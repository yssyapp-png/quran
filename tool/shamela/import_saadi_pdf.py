#!/usr/bin/env python3
"""Verify and bundle Tafsir al-Saadi from a structured Shamela PDF.

The importer does not infer section boundaries from typography. It uses the
PDF outline destinations (surah, starting ayah, page and vertical position),
then validates the resulting groups against the project's 6,236-ayah map.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unicodedata

from pypdf import PdfReader

from extract_tafsir_saadi import (
    BOOK_ID,
    EXPECTED_AYAH_COUNT,
    EXPECTED_BOOK_NAME,
    EXPECTED_MUSHAF_PAGES,
    fail,
    install_staging,
    load_quran_map,
)

EXPECTED_AUTHOR = "عبد الرحمن السعدي"
EXPECTED_PDF_PAGES = 1333
EXPECTED_GROUPS = 1998
KNOWN_MISSING_OUTLINE = {
    # This edition contains Surah 104 and its complete text on PDF page 1285,
    # but omits the surah and ayah destinations from the outline. The position
    # points to the verified beginning of the Quran quotation, not a guessed
    # paragraph boundary.
    104: {"page": 1284, "top": 571.0},
}


def _without_marks(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(
        character
        for character in normalized
        if unicodedata.category(character) not in {"Mn", "Cf"}
    ).replace("ـ", "")


def _ascii_digits(value: str) -> str:
    translation = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
    return value.translate(translation)


def _find_pdftotext(explicit: Path | None) -> Path:
    if explicit is not None:
        candidate = explicit.expanduser().resolve()
        if candidate.is_file():
            return candidate
        fail(f"أداة pdftotext غير موجودة: {candidate}")
    system = shutil.which("pdftotext")
    if system:
        return Path(system)
    bundled = (
        Path.home()
        / ".cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler"
        / "poppler/bin/pdftotext"
    )
    if bundled.is_file():
        return bundled
    fail("تعذر العثور على pdftotext. ثبّت Poppler أو مرّر --pdftotext.")


def _verify_pdf(reader: PdfReader) -> None:
    if reader.is_encrypted:
        fail("ملف PDF مشفر ولا يمكن اعتماده كمصدر قابل لإعادة البناء.")
    metadata = reader.metadata or {}
    title = str(metadata.get("/Title", "")).strip()
    author = str(metadata.get("/Author", "")).strip()
    if title != EXPECTED_BOOK_NAME or author != EXPECTED_AUTHOR:
        fail(
            "هوية ملف PDF لا تطابق النسخة المعتمدة من تفسير السعدي: "
            f"العنوان={title!r}، المؤلف={author!r}."
        )
    if len(reader.pages) != EXPECTED_PDF_PAGES:
        fail(
            f"عدد صفحات PDF تغير: المتوقع {EXPECTED_PDF_PAGES}، "
            f"الموجود {len(reader.pages)}."
        )


def _surah_metadata(quran_file: Path) -> tuple[list[str], dict[int, int]]:
    records = json.loads(quran_file.read_text(encoding="utf-8"))
    names: dict[int, str] = {}
    maxima: dict[int, int] = {}
    for record in records:
        surah = record["sura_no"]
        names[surah] = record["sura_name_ar"]
        maxima[surah] = max(maxima.get(surah, 0), record["aya_no"])
    if set(names) != set(range(1, 115)):
        fail("خريطة القرآن لا تحتوي أسماء السور الـ114 كاملة.")
    return [names[number] for number in range(1, 115)], maxima


def _outline_groups(
    reader: PdfReader,
    expected_names: list[str],
    maxima: dict[int, int],
) -> list[dict[str, object]]:
    outline = reader.outline
    start_index = next(
        (
            index
            for index, item in enumerate(outline)
            if not isinstance(item, list) and str(getattr(item, "title", "")) == "الفاتحة"
        ),
        None,
    )
    if start_index is None:
        fail("لم يعثر على بداية فهرس السور في PDF.")
    tail = outline[start_index:]
    if len(tail) % 2:
        fail("بنية فهرس PDF غير متوقعة؛ عنوان سورة بلا قائمة آيات.")
    actual_pairs = []
    for index in range(0, len(tail), 2):
        heading, children = tail[index : index + 2]
        if isinstance(heading, list) or not isinstance(children, list):
            fail("بنية فهرس PDF غير متوقعة عند أحد عناوين السور.")
        actual_pairs.append((heading, children))

    pair_index = 0
    groups: list[dict[str, object]] = []
    for surah in range(1, 115):
        expected_name = expected_names[surah - 1]
        next_actual_name = (
            str(getattr(actual_pairs[pair_index][0], "title", ""))
            if pair_index < len(actual_pairs)
            else ""
        )
        if _without_marks(next_actual_name) != _without_marks(expected_name):
            known = KNOWN_MISSING_OUTLINE.get(surah)
            if known is None:
                fail(
                    f"فهرس PDF فقد سورة أو غير ترتيبها عند {expected_name!r}؛ "
                    f"العنوان التالي {next_actual_name!r}."
                )
            groups.append(
                {
                    "surah": surah,
                    "surah_name": expected_name,
                    "start_ayah": 1,
                    "page": known["page"],
                    "top": known["top"],
                    "outline_marker_missing": True,
                }
            )
            continue

        heading, children = actual_pairs[pair_index]
        pair_index += 1
        actual_name = str(getattr(heading, "title", ""))
        starts: list[int] = []
        for destination in children:
            title = _ascii_digits(str(getattr(destination, "title", "")))
            if not title.isdigit():
                fail(f"عنوان آية غير رقمي في فهرس سورة {actual_name}: {title!r}")
            start_ayah = int(title)
            starts.append(start_ayah)
            groups.append(
                {
                    "surah": surah,
                    "surah_name": actual_name,
                    "start_ayah": start_ayah,
                    "page": reader.get_destination_page_number(destination),
                    "top": float(destination.top),
                }
            )
        if (
            not starts
            or starts[0] != 1
            or starts != sorted(set(starts))
            or starts[-1] > maxima[surah]
        ):
            fail(f"بدايات مجموعات سورة {actual_name} غير مكتملة أو غير مرتبة.")

    if pair_index != len(actual_pairs):
        fail("بقيت عناوين سور غير متوقعة بعد نهاية سورة الناس.")

    if len(groups) != EXPECTED_GROUPS:
        fail(
            f"عدد مجموعات التفسير تغير: المتوقع {EXPECTED_GROUPS}، "
            f"الموجود {len(groups)}."
        )
    for index, group in enumerate(groups):
        surah = int(group["surah"])
        start = int(group["start_ayah"])
        if index + 1 < len(groups) and int(groups[index + 1]["surah"]) == surah:
            end = int(groups[index + 1]["start_ayah"]) - 1
        else:
            end = maxima[surah]
        if end < start:
            fail(f"نطاق آيات سالب عند {surah}:{start}.")
        group["end_ayah"] = end

    coverage = sum(
        int(group["end_ayah"]) - int(group["start_ayah"]) + 1 for group in groups
    )
    if coverage != EXPECTED_AYAH_COUNT:
        fail(f"فهرس PDF يغطي {coverage} آية بدلًا من {EXPECTED_AYAH_COUNT}.")
    return groups


def _extract_crop(
    pdftotext: Path,
    pdf: Path,
    page_number: int,
    y: float,
    height: float,
) -> str:
    if height <= 1:
        return ""
    command = [
        str(pdftotext),
        "-f",
        str(page_number + 1),
        "-l",
        str(page_number + 1),
        "-layout",
        "-nopgbrk",
        "-enc",
        "UTF-8",
        "-x",
        "20",
        "-y",
        str(max(0, math.floor(y))),
        "-W",
        "556",
        "-H",
        str(max(1, math.ceil(height))),
        str(pdf),
        "-",
    ]
    result = subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        timeout=30,
    )
    return result.stdout


def _clean_section(raw: str, expected_start: int, marker_missing: bool = False) -> str:
    raw = "".join(
        character for character in raw if unicodedata.category(character) != "Cf"
    ).replace("ـ", "")
    lines = [" ".join(line.split()) for line in raw.splitlines()]
    lines = [line for line in lines if line and "Shamela.org" not in line]
    if not lines:
        fail(f"مقطع التفسير عند الآية {expected_start} فارغ.")

    if not marker_missing:
        marker = _ascii_digits(lines.pop(0))
        marker_numbers = [int(value) for value in re.findall(r"\d+", marker)]
        if expected_start not in marker_numbers:
            fail(
                f"علامة بداية المقطع لا تطابق الآية {expected_start}: {marker!r}."
            )

    if lines and "تفسير سورة" in lines[0]:
        lines.pop(0)
        if lines and (
            lines[0].startswith("وهي")
            or "مكية" in lines[0]
            or "مدنية" in lines[0]
            or "السلام" in lines[0]
        ):
            lines.pop(0)

    next_surah_heading = next(
        (
            index
            for index, line in enumerate(lines)
            if "تفسير سورة" in line
        ),
        None,
    )
    if next_surah_heading is not None:
        lines = lines[:next_surah_heading]
    separator = next((index for index, line in enumerate(lines) if set(line) == {"_"}), None)
    if separator is not None and separator >= len(lines) * 0.7:
        lines = lines[:separator]
    elif separator is not None:
        lines.pop(separator)
    text = " ".join(lines)
    text = re.sub(r"-\[\s*[٠-٩0-9]+\s*\]-", " ", text)
    text = re.sub(r"\s+([،؛؟.!:])", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _extract_sections(
    reader: PdfReader,
    pdftotext: Path,
    pdf: Path,
    groups: list[dict[str, object]],
) -> None:
    for index, group in enumerate(groups):
        start_page = int(group["page"])
        start_top = float(group["top"])
        page_height = float(reader.pages[start_page].mediabox.height)
        next_group = groups[index + 1] if index + 1 < len(groups) else None
        end_page = int(next_group["page"]) if next_group else start_page
        end_top = float(next_group["top"]) if next_group else 36.0
        chunks: list[str] = []

        for page in range(start_page, end_page + 1):
            height = float(reader.pages[page].mediabox.height)
            content_top = 42.0
            content_bottom = height - 36.0
            y_start = max(content_top, height - start_top) if page == start_page else content_top
            y_end = min(content_bottom, height - end_top) if page == end_page else content_bottom
            chunks.append(_extract_crop(pdftotext, pdf, page, y_start, y_end - y_start))

        group["text"] = _clean_section(
            "\n".join(chunks),
            int(group["start_ayah"]),
            bool(group.get("outline_marker_missing", False)),
        )
        if (index + 1) % 200 == 0 or index + 1 == len(groups):
            print(f"تم التحقق من {index + 1}/{len(groups)} مجموعة تفسير.")


def _write_assets(
    staging: Path,
    quran_map: dict[int, tuple[str, int]],
    groups: list[dict[str, object]],
    source_file: Path,
) -> None:
    ayah_lookup = {verse_key: (ayah_id, page) for ayah_id, (verse_key, page) in quran_map.items()}
    by_page: dict[int, list[dict[str, str]]] = {
        page: [] for page in range(1, EXPECTED_MUSHAF_PAGES + 1)
    }
    claimed: set[str] = set()
    for group in groups:
        surah = int(group["surah"])
        start = int(group["start_ayah"])
        end = int(group["end_ayah"])
        text = str(group["text"])
        keys_by_page: dict[int, list[str]] = {}
        for ayah in range(start, end + 1):
            key = f"{surah}:{ayah}"
            if key not in ayah_lookup or key in claimed:
                fail(f"ربط آية مكرر أو غير موجود: {key}")
            claimed.add(key)
            page = ayah_lookup[key][1]
            keys_by_page.setdefault(page, []).append(key)
        if text:
            for page, keys in keys_by_page.items():
                by_page[page].append({"verse_key": keys[0], "text": text})

    if len(claimed) != EXPECTED_AYAH_COUNT:
        fail(f"الناتج يغطي {len(claimed)} آية فقط.")
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
        "author": EXPECTED_AUTHOR,
        "source_type": "structured_shamela_pdf",
        "source_file": source_file.name,
        "source_file_sha256": digest,
        "source_pdf_pages": EXPECTED_PDF_PAGES,
        "section_text_includes_quran_quotation": True,
        "ayahs_verified": EXPECTED_AYAH_COUNT,
        "mushaf_pages": EXPECTED_MUSHAF_PAGES,
        "tafsir_groups": len(groups),
        "text_groups": sum(bool(group["text"]) for group in groups),
        "groups_without_independent_commentary": [
            f'{group["surah"]}:{group["start_ayah"]}'
            for group in groups
            if not group["text"]
        ],
        "tafsir_entries": entry_count,
        "distribution_review_required": True,
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (staging / "SOURCE.md").write_text(
        "# مصدر تفسير السعدي\n\n"
        "استُخرج النص محليًا من ملف PDF منظم أنشأته المكتبة الشاملة، "
        "بعد التحقق من بيانات المؤلف والعنوان والفهرس وتغطية الآيات.\n\n"
        f"- ملف المصدر: `{source_file.name}`\n"
        f"- SHA-256: `{digest}`\n"
        f"- مجموعات التفسير: {len(groups)}\n"
        f"- الآيات المغطاة: {EXPECTED_AYAH_COUNT}\n\n"
        "> يلزم توثيق حق إعادة توزيع نص هذه الطبعة قبل النشر العام للتطبيق.\n",
        encoding="utf-8",
    )


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="ملف PDF المنظم")
    parser.add_argument("--pdftotext", type=Path)
    parser.add_argument(
        "--output", type=Path, default=project_root / "assets/data/tafsir_saadi"
    )
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()

    source_file = args.input.expanduser().resolve()
    if not source_file.is_file():
        fail(f"ملف PDF غير موجود: {source_file}")
    pdftotext = _find_pdftotext(args.pdftotext)
    reader = PdfReader(source_file)
    _verify_pdf(reader)
    quran_file = project_root / "assets/data/hafs_smart_v8.json"
    expected_names, maxima = _surah_metadata(quran_file)
    groups = _outline_groups(reader, expected_names, maxima)
    _extract_sections(reader, pdftotext, source_file, groups)
    quran_map = load_quran_map(quran_file)

    with tempfile.TemporaryDirectory(prefix="quran-pdf-saadi-") as temporary:
        staging = Path(temporary) / "tafsir_saadi"
        _write_assets(staging, quran_map, groups, source_file)
        install_staging(staging, args.output.resolve(), args.replace, project_root)
    print("اكتمل استخراج تفسير السعدي والتحقق من ربطه بصفحات المصحف.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"خطأ: {error}")
        raise SystemExit(1)
