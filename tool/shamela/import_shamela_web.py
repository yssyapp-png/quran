#!/usr/bin/env python3
"""Build the bundled Tafsir al-Saadi assets from Shamela's official book 42.

The supplied PDF is retained as a visual reference, but its Arabic text layer
splits some letters and diacritics.  This importer fetches the same book from
the official Shamela text edition, validates every indexed tafsir group, and
writes the existing per-Mushaf-page asset format used by the Flutter app.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import tempfile
import time
from urllib.error import URLError
from urllib.request import Request, urlopen

from extract_tafsir_saadi import (
    BOOK_ID,
    EXPECTED_AYAH_COUNT,
    EXPECTED_BOOK_NAME,
    EXPECTED_MUSHAF_PAGES,
    fail,
)


BASE_URL = f"https://shamela.ws/book/{BOOK_ID}"
USER_AGENT = "QuranY-SaadiImporter/1.0 (offline Flutter content builder)"
_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
_LAST_SURAH_LEAF = (2140, "114:1")


def fetch(url: str) -> str:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urlopen(request, timeout=8) as response:
                return response.read().decode("utf-8")
        except (TimeoutError, URLError) as error:
            last_error = error
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"تعذر الاتصال بالمصدر الرسمي: {last_error}")


class NassTextParser(HTMLParser):
    """Extract the readable text inside the site's `div.nass` container."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._depth = 0
        self._active = False
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = dict(attrs)
        if tag == "div" and "nass" in (attributes.get("class") or "").split():
            self._active = True
            self._depth = 1
            return
        if not self._active:
            return
        if tag == "div":
            self._depth += 1
        if tag in {"br", "p", "li", "h1", "h2", "h3", "h4", "h5", "h6"}:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if not self._active:
            return
        if tag in {"p", "li", "h1", "h2", "h3", "h4", "h5", "h6"}:
            self.parts.append("\n")
        if tag == "div":
            self._depth -= 1
            if self._depth == 0:
                self._active = False

    def handle_data(self, data: str) -> None:
        if self._active:
            self.parts.append(data)


def plain_text(html: str) -> str:
    parser = NassTextParser()
    parser.feed(html)
    parser.close()
    if not parser.parts:
        fail("لم يُعثر على نص التفسير في استجابة المكتبة الشاملة.")
    lines = [" ".join(line.split()) for line in "".join(parser.parts).splitlines()]
    return "\n".join(line for line in lines if line).strip()


def chapter_ids(index_html: str) -> list[int]:
    ids = sorted({int(value) for value in re.findall(r'data-id="(\d+)"', index_html)})
    if len(ids) < 114:
        fail("فهرس المكتبة الشاملة لا يحتوي فصول المصحف كاملة.")
    return ids


def tafsir_page_ids(index_html: str, workers: int) -> list[tuple[int, str]]:
    """Return each official tafsir group with its canonical first ayah key."""
    chapters = chapter_ids(index_html)
    # The index has a collapsible node for the introduction and for the first
    # 113 surahs. Surat An-Nas has one section and is therefore a leaf link,
    # not a collapsible node; it is added explicitly and checked below.
    if len(chapters) != 114:
        fail("عدد عقد فهرس الكتاب غير متوقع؛ أوقف الاستيراد للحماية.")
    page_ids: list[tuple[int, str]] = []

    def fetch_chapter(surah: int, chapter_id: int) -> list[tuple[int, str]]:
        html = fetch(f"https://shamela.ws/ajax/titlechilds/{BOOK_ID}/{chapter_id}")
        values = re.findall(rf'/book/{BOOK_ID}/(\d+)">([^<]+)</a>', html)
        result: list[tuple[int, str]] = []
        for page_id, label in values:
            normalized = label.strip().translate(_ARABIC_DIGITS)
            if normalized.isdigit():
                result.append((int(page_id), f"{surah}:{int(normalized)}"))
        return result

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(fetch_chapter, surah, chapter_id): surah
            for surah, chapter_id in enumerate(chapters[1:], start=1)
        }
        for future in as_completed(futures):
            page_ids.extend(future.result())
    page_ids.append(_LAST_SURAH_LEAF)
    result = sorted(page_ids, key=lambda item: item[0])
    if len(result) != 1998 or len({key for _, key in result}) != len(result):
        fail(f"فهرس تفسير السعدي غير مكتمل: عُثر على {len(result)} قسمًا فقط.")
    return result


def fetch_group(page_id: int, verse_key: str) -> tuple[str, str]:
    text = plain_text(fetch(f"{BASE_URL}/{page_id}"))
    return verse_key, text


def load_existing_entries(asset_dir: Path) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for page in range(1, EXPECTED_MUSHAF_PAGES + 1):
        payload = json.loads((asset_dir / f"{page:03d}.json").read_text(encoding="utf-8"))
        entries = payload.get("entries")
        if not isinstance(entries, list):
            fail(f"ملف الأصول المحلي {page:03d} غير صالح.")
        for index, entry in enumerate(entries):
            key = entry.get("verse_key") if isinstance(entry, dict) else None
            text = entry.get("text") if isinstance(entry, dict) else None
            if not isinstance(key, str) or not isinstance(text, str):
                fail(f"مفتاح تفسير محلي مكرر أو غير صالح في الصفحة {page:03d}.")
            result.append({"verse_key": key, "text": text})
    return result


def write_assets(
    staging: Path,
    current_dir: Path,
    groups: dict[str, str],
) -> None:
    staging.mkdir(parents=True)
    existing = load_existing_entries(current_dir)
    canonical_by_old_text: dict[str, str] = {}
    for entry in existing:
        canonical_by_old_text.setdefault(entry["text"], entry["verse_key"])
    expected_keys = set(canonical_by_old_text.values())
    if expected_keys != set(groups):
        fail(
            "فشل تحقق الربط بين فهرس الشاملة وصفحات المصحف: "
            f"المصدر {len(groups)} مجموعة، والمتوقع {len(expected_keys)}."
        )
    text_by_old_text = {old: groups[key] for old, key in canonical_by_old_text.items()}

    for page in range(1, EXPECTED_MUSHAF_PAGES + 1):
        source = json.loads((current_dir / f"{page:03d}.json").read_text(encoding="utf-8"))
        entries = source["entries"]
        updated = [
            {"verse_key": entry["verse_key"], "text": text_by_old_text[entry["text"]]}
            for entry in entries
        ]
        (staging / f"{page:03d}.json").write_text(
            json.dumps(
                {"schema_version": 1, "book_id": BOOK_ID, "page": page, "entries": updated},
                ensure_ascii=False,
                separators=(",", ":"),
            )
            + "\n",
            encoding="utf-8",
        )

    previous_manifest_path = current_dir / "manifest.json"
    previous_manifest = json.loads(previous_manifest_path.read_text(encoding="utf-8"))
    source_reference_hash = previous_manifest.get("source_file_sha256")
    if not isinstance(source_reference_hash, str) or not re.fullmatch(
        r"[a-f0-9]{64}", source_reference_hash
    ):
        # The PDF remains only a visual-reference checksum. The displayed text
        # is independently fetched from Shamela's clean text edition.
        source_reference_hash = hashlib.sha256(BASE_URL.encode("utf-8")).hexdigest()

    manifest = {
        "schema_version": 1,
        "book_id": BOOK_ID,
        "book_name": EXPECTED_BOOK_NAME,
        "source": BASE_URL,
        "text_edition": "المكتبة الشاملة الرسمية - كتاب 42",
        "author": "عبد الرحمن السعدي",
        "source_type": "shamela_official_web_text",
        "source_file_sha256": source_reference_hash,
        "ayahs_verified": EXPECTED_AYAH_COUNT,
        "mushaf_pages": EXPECTED_MUSHAF_PAGES,
        "tafsir_groups": len(groups),
        "text_groups": len(groups),
        "groups_without_independent_commentary": [],
        "tafsir_entries": len(existing),
        "offline_ready": True,
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (staging / "SOURCE.md").write_text(
        "# مصدر تفسير السعدي\n\n"
        "النص المضمّن مأخوذ من الكتاب 42 في المكتبة الشاملة الرسمية:\n\n"
        f"{BASE_URL}\n\n"
        "استُخدمت هذه النسخة النصية لأن طبقة النص في ملف PDF المصوّر تُظهر "
        "بعض الحروف العربية متباعدة، بينما يظل PDF مرجعًا بصريًا منفصلًا.\n",
        encoding="utf-8",
    )


def install(staging: Path, target: Path) -> None:
    backup = target.with_name(f"{target.name}.pdf-text-layer-backup")
    if backup.exists():
        shutil.rmtree(backup)
    shutil.move(str(target), str(backup))
    shutil.move(str(staging), str(target))
    print(f"حُفظت أصول PDF السابقة في: {backup}")


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=project_root / "assets" / "data" / "tafsir_saadi"
    )
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()
    if not (1 <= args.workers <= 8):
        fail("عدد الاتصالات يجب أن يكون بين 1 و8.")

    target = args.output.resolve()
    if not target.is_dir():
        fail("أصول تفسير السعدي الحالية غير موجودة.")
    index_html = fetch(BASE_URL)
    page_ids = tafsir_page_ids(index_html, args.workers)
    groups: dict[str, str] = {}
    failures: list[str] = []
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {
            executor.submit(fetch_group, page_id, verse_key): (page_id, verse_key)
            for page_id, verse_key in page_ids
        }
        for number, future in enumerate(as_completed(futures), start=1):
            page_id, verse_key = futures[future]
            try:
                key, text = future.result()
                if key != verse_key or key in groups:
                    fail(f"تكرر قسم التفسير {verse_key} في فهرس الشاملة.")
                groups[key] = text
            except Exception as error:  # report every failed remote page together
                failures.append(f"{page_id}: {error}")
            if number % 100 == 0:
                print(f"تم التحقق من {number}/{len(page_ids)} قسمًا…")
            time.sleep(0.01)
    if failures:
        fail("تعذر تنزيل أقسام من الشاملة: " + "; ".join(failures[:5]))

    with tempfile.TemporaryDirectory(prefix="quran-shamela-web-") as temporary:
        staging = Path(temporary) / "tafsir_saadi"
        write_assets(staging, target, groups)
        install(staging, target)
    print("اكتمل بناء تفسير السعدي بنص عربي سليم ومتاح دون إنترنت.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"خطأ: {error}")
        raise SystemExit(1)
