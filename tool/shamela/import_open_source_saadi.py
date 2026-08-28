#!/usr/bin/env python3
"""Verify and bundle the official QUL Tafsir al-Saadi JSON export."""

from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import tempfile

from extract_tafsir_saadi import (
    BOOK_ID,
    EXPECTED_AUTHOR_ID,
    EXPECTED_AYAH_COUNT,
    EXPECTED_BOOK_NAME,
    EXPECTED_MUSHAF_PAGES,
    fail,
    install_staging,
    load_quran_map,
)

SOURCE_PAGE = "https://qul.tarteel.ai/resources/tafsir/24"


class _PlainTextParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() == "br":
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"p", "div", "li", "h1", "h2", "h3", "h4", "h5", "h6"}:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def plain_text(value: str) -> str:
    parser = _PlainTextParser()
    parser.feed(value)
    parser.close()
    lines = [" ".join(line.split()) for line in "".join(parser.parts).splitlines()]
    return "\n".join(line for line in lines if line).strip()


def load_and_validate_groups(
    source_file: Path,
    expected_keys: set[str],
) -> dict[str, tuple[str, list[str]]]:
    try:
        payload = json.loads(source_file.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"تعذر قراءة ملف QUL JSON: {error}")
    if not isinstance(payload, dict):
        fail("ملف QUL يجب أن يكون كائن JSON مرتبطًا بمفاتيح السورة والآية.")
    if set(payload) != expected_keys or len(payload) != EXPECTED_AYAH_COUNT:
        missing = sorted(expected_keys - set(payload))[:10]
        extra = sorted(set(payload) - expected_keys)[:10]
        fail(
            "ملف QUL لا يغطي آيات المصحف الـ6236 كاملة. "
            f"مفقود: {missing or 'لا يوجد'}؛ زائد: {extra or 'لا يوجد'}."
        )

    groups: dict[str, tuple[str, list[str]]] = {}
    claimed: dict[str, str] = {}
    for root_key, value in payload.items():
        if isinstance(value, str):
            continue
        if not isinstance(value, dict):
            fail(f"قيمة غير صحيحة للآية {root_key}.")
        raw_text = value.get("text")
        raw_keys = value.get("ayah_keys", [root_key])
        if not isinstance(raw_text, str) or not isinstance(raw_keys, list):
            fail(f"مجموعة تفسير غير صحيحة عند الآية {root_key}.")
        text = plain_text(raw_text)
        ayah_keys = [key for key in raw_keys if isinstance(key, str)]
        if not text or not ayah_keys or len(ayah_keys) != len(raw_keys):
            fail(f"نص أو مفاتيح مجموعة التفسير غير مكتملة عند {root_key}.")
        if root_key not in ayah_keys or len(set(ayah_keys)) != len(ayah_keys):
            fail(f"مجموعة الآية {root_key} لا تشير إلى نفسها أو تحتوي تكرارًا.")
        for key in ayah_keys:
            if key not in expected_keys or key in claimed:
                fail(f"ربط آية مكرر أو غير متوقع داخل المجموعة {root_key}: {key}")
            claimed[key] = root_key
        groups[root_key] = (text, ayah_keys)

    for key, value in payload.items():
        root_key = claimed.get(key)
        if root_key is None:
            fail(f"الآية {key} غير مرتبطة بأي نص تفسير.")
        if key == root_key:
            if isinstance(value, str):
                fail(f"الآية الرئيسية {key} لا تحتوي نص التفسير.")
        elif value != root_key:
            fail(f"مؤشر المجموعة للآية {key} غير صحيح.")
    return groups


def write_assets(
    staging: Path,
    quran_map: dict[int, tuple[str, int]],
    groups: dict[str, tuple[str, list[str]]],
    source_file: Path,
) -> None:
    key_to_page = {verse_key: page for verse_key, page in quran_map.values()}
    by_page: dict[int, list[dict[str, str]]] = {
        page: [] for page in range(1, EXPECTED_MUSHAF_PAGES + 1)
    }
    for text, ayah_keys in groups.values():
        keys_by_page: dict[int, list[str]] = {}
        for key in ayah_keys:
            keys_by_page.setdefault(key_to_page[key], []).append(key)
        for page, page_keys in keys_by_page.items():
            by_page[page].append({"verse_key": page_keys[0], "text": text})

    staging.mkdir(parents=True)
    entry_count = 0
    for page in range(1, EXPECTED_MUSHAF_PAGES + 1):
        entries = by_page[page]
        if not entries:
            fail(f"لا يوجد تفسير مرتبط بصفحة المصحف {page}.")
        entry_count += len(entries)
        (staging / f"{page:03d}.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "book_id": BOOK_ID,
                    "page": page,
                    "entries": entries,
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
            + "\n",
            encoding="utf-8",
        )

    digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
    manifest = {
        "schema_version": 1,
        "book_id": BOOK_ID,
        "book_name": EXPECTED_BOOK_NAME,
        "author_id": EXPECTED_AUTHOR_ID,
        "source": SOURCE_PAGE,
        "source_file_sha256": digest,
        "ayahs_verified": EXPECTED_AYAH_COUNT,
        "mushaf_pages": EXPECTED_MUSHAF_PAGES,
        "tafsir_groups": len(groups),
        "tafsir_entries": entry_count,
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (staging / "SOURCE.md").write_text(
        "# مصدر تفسير السعدي\n\n"
        f"تم الاستيراد من ملف JSON الرسمي المتاح في: {SOURCE_PAGE}\n\n"
        f"SHA-256: `{digest}`\n",
        encoding="utf-8",
    )


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="ملف JSON المنزّل من QUL")
    parser.add_argument(
        "--output", type=Path, default=project_root / "assets" / "data" / "tafsir_saadi"
    )
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()

    source_file = args.input.expanduser().resolve()
    if not source_file.is_file():
        fail(f"ملف QUL غير موجود: {source_file}")
    quran_map = load_quran_map(project_root / "assets" / "data" / "hafs_smart_v8.json")
    expected_keys = {verse_key for verse_key, _ in quran_map.values()}
    groups = load_and_validate_groups(source_file, expected_keys)

    with tempfile.TemporaryDirectory(prefix="quran-qul-saadi-") as temporary:
        staging = Path(temporary) / "tafsir_saadi"
        write_assets(staging, quran_map, groups, source_file)
        install_staging(staging, args.output.resolve(), args.replace, project_root)
    print("اكتمل التحقق من تفسير السعدي وربطه بصفحات المصحف دون بيانات ناقصة.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"خطأ: {error}")
        raise SystemExit(1)
