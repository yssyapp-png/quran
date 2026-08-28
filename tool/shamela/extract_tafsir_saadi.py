#!/usr/bin/env python3
"""Extract Tafsir al-Saadi from a locally installed Shamela library."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile

BOOK_ID = 42
EXPECTED_BOOK_NAME = "تفسير السعدي = تيسير الكريم الرحمن"
EXPECTED_AUTHOR_ID = 128
EXPECTED_AYAH_COUNT = 6236
EXPECTED_MUSHAF_PAGES = 604


def fail(message: str) -> "None":
    raise RuntimeError(message)


def find_java_home() -> Path:
    candidates = [
        os.environ.get("JAVA_HOME"),
        "/Applications/Android Studio.app/Contents/jbr/Contents/Home",
    ]
    for candidate in candidates:
        if candidate and (Path(candidate) / "bin" / "javac").is_file():
            return Path(candidate)
    fail("لم يتم العثور على JDK. افتح Android Studio أو عيّن JAVA_HOME ثم أعد المحاولة.")


def verify_book_identity(master_db: Path) -> None:
    with sqlite3.connect(master_db) as connection:
        record = connection.execute(
            "SELECT book_name, main_author, major_ondisk FROM book WHERE book_id = ?",
            (BOOK_ID,),
        ).fetchone()
    if record is None:
        fail("لم يعثر على الكتاب رقم 42 في فهرس المكتبة الشاملة.")
    name, author_id, on_disk = record
    if name != EXPECTED_BOOK_NAME or author_id != EXPECTED_AUTHOR_ID:
        fail("توقّف الاستخراج لأن هوية الكتاب رقم 42 لا تطابق تفسير السعدي المعتمد.")
    if not on_disk:
        fail(
            "تفسير السعدي مسجل في الشاملة لكنه غير منزّل محليًا. "
            "نزّل الكتاب رقم 42 من داخل الشاملة ثم أعد تشغيل الأداة."
        )


def load_quran_map(quran_json: Path) -> dict[int, tuple[str, int]]:
    records = json.loads(quran_json.read_text(encoding="utf-8"))
    if not isinstance(records, list) or len(records) != EXPECTED_AYAH_COUNT:
        fail("ملف خريطة القرآن لا يحتوي على 6236 آية.")
    result: dict[int, tuple[str, int]] = {}
    for record in records:
        ayah_id = record.get("id")
        surah = record.get("sura_no")
        ayah = record.get("aya_no")
        page = record.get("page")
        if not all(isinstance(value, int) for value in (ayah_id, surah, ayah, page)):
            fail("يوجد سجل غير صحيح في خريطة القرآن.")
        if not 1 <= page <= EXPECTED_MUSHAF_PAGES:
            fail(f"رقم صفحة مصحف غير صحيح للآية العالمية {ayah_id}.")
        result[ayah_id] = (f"{surah}:{ayah}", page)
    if set(result) != set(range(1, EXPECTED_AYAH_COUNT + 1)):
        fail("تسلسل أرقام الآيات في خريطة القرآن غير مكتمل.")
    return result


def export_lucene_pages(
    project_root: Path, shamela_root: Path, output_jsonl: Path
) -> dict[int, str]:
    java_home = find_java_home()
    lucene_dir = shamela_root / "app" / "lucene" / "2"
    page_index = shamela_root / "database" / "store" / "page"
    source = project_root / "tool" / "shamela" / "ShamelaPageExporter.java"
    if not (lucene_dir / "lucene-core-10.4.0.jar").is_file() or not page_index.is_dir():
        fail("لم يعثر على فهرس نصوص الشاملة أو مكتبات Lucene المطلوبة.")

    with tempfile.TemporaryDirectory(prefix="quran-shamela-java-") as classes:
        classpath = f"{lucene_dir}/*"
        subprocess.run(
            [str(java_home / "bin" / "javac"), "-cp", classpath, "-d", classes, str(source)],
            check=True,
        )
        subprocess.run(
            [
                str(java_home / "bin" / "java"),
                "-cp",
                f"{classes}:{classpath}",
                "ShamelaPageExporter",
                str(page_index),
                str(BOOK_ID),
                str(output_jsonl),
            ],
            check=True,
        )

    pages: dict[int, str] = {}
    with output_jsonl.open(encoding="utf-8") as stream:
        for line in stream:
            record = json.loads(line)
            page_id, text = record.get("page_id"), record.get("text")
            if not isinstance(page_id, int) or not isinstance(text, str) or not text.strip():
                fail("صدّر Lucene سجل صفحة غير صحيح.")
            if page_id in pages:
                fail(f"تكرر معرّف صفحة الشاملة {page_id}.")
            pages[page_id] = text.strip()
    if not pages:
        fail("لم تُستخرج أي صفحة من تفسير السعدي.")
    return pages


def load_tafsir_links(tafseer_db: Path) -> list[tuple[int, int]]:
    with sqlite3.connect(tafseer_db) as connection:
        links = connection.execute(
            "SELECT key_id, page_id FROM service WHERE book_id = ? ORDER BY key_id, page_id",
            (BOOK_ID,),
        ).fetchall()
    ayah_ids = {key_id for key_id, _ in links}
    if ayah_ids != set(range(1, EXPECTED_AYAH_COUNT + 1)):
        fail(
            "ربط تفسير السعدي بالآيات غير مكتمل في الشاملة. "
            "فعّل الكتاب ضمن خدمة التفسير في الشاملة ثم أعد المحاولة."
        )
    return links


def write_assets(
    staging: Path,
    links: list[tuple[int, int]],
    tafsir_pages: dict[int, str],
    quran_map: dict[int, tuple[str, int]],
) -> None:
    grouped: dict[int, dict[int, tuple[str, str]]] = {}
    missing_page_ids: set[int] = set()
    for ayah_id, tafsir_page_id in links:
        text = tafsir_pages.get(tafsir_page_id)
        if text is None:
            missing_page_ids.add(tafsir_page_id)
            continue
        verse_key, mushaf_page = quran_map[ayah_id]
        grouped.setdefault(mushaf_page, {}).setdefault(tafsir_page_id, (verse_key, text))
    if missing_page_ids:
        sample = ", ".join(str(value) for value in sorted(missing_page_ids)[:10])
        fail(f"نصوص صفحات مرتبطة غير موجودة في فهرس الشاملة: {sample}")
    if set(grouped) != set(range(1, EXPECTED_MUSHAF_PAGES + 1)):
        fail("التفسير المستخرج لا يغطي صفحات المصحف الـ604 كاملة.")

    staging.mkdir(parents=True)
    entry_count = 0
    for mushaf_page in range(1, EXPECTED_MUSHAF_PAGES + 1):
        entries = [
            {"verse_key": verse_key, "text": text}
            for verse_key, text in grouped[mushaf_page].values()
        ]
        entry_count += len(entries)
        payload = {
            "schema_version": 1,
            "book_id": BOOK_ID,
            "page": mushaf_page,
            "entries": entries,
        }
        target = staging / f"{mushaf_page:03d}.json"
        target.write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
    manifest = {
        "schema_version": 1,
        "book_id": BOOK_ID,
        "book_name": EXPECTED_BOOK_NAME,
        "author_id": EXPECTED_AUTHOR_ID,
        "mushaf_pages": EXPECTED_MUSHAF_PAGES,
        "tafsir_entries": entry_count,
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def install_staging(staging: Path, output: Path, replace: bool, project_root: Path) -> None:
    if output.exists():
        contents = {path.name for path in output.iterdir()}
        placeholder_only = contents <= {"README.md"}
        if placeholder_only:
            shutil.rmtree(output)
        elif not replace:
            fail(f"المجلد {output} موجود. استخدم --replace بعد مراجعة النسخة الجديدة.")
        else:
            stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            backup = project_root / "build" / "tafsir_backups" / stamp
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(output), str(backup))
            print(f"حُفظت النسخة السابقة في: {backup}")
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(staging), str(output))


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    default_shamela = Path.home() / "Library" / "Application Support" / "Shamela"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shamela-root", type=Path, default=default_shamela)
    parser.add_argument(
        "--output", type=Path, default=project_root / "assets" / "data" / "tafsir_saadi"
    )
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()

    shamela_root = args.shamela_root.expanduser().resolve()
    master_db = shamela_root / "database" / "master.db"
    tafseer_db = shamela_root / "database" / "service" / "tafseer.db"
    book_db = shamela_root / "database" / "book" / "042" / "42.db"
    for required in (master_db, tafseer_db):
        if not required.is_file():
            fail(f"ملف الشاملة المطلوب غير موجود: {required}")
    verify_book_identity(master_db)
    if not book_db.is_file():
        fail("ملف الكتاب 42.db غير موجود؛ نزّل تفسير السعدي من داخل الشاملة أولًا.")

    quran_map = load_quran_map(project_root / "assets" / "data" / "hafs_smart_v8.json")
    links = load_tafsir_links(tafseer_db)
    with tempfile.TemporaryDirectory(prefix="quran-tafsir-saadi-") as temporary:
        temporary_path = Path(temporary)
        pages = export_lucene_pages(
            project_root, shamela_root, temporary_path / "book-42.jsonl"
        )
        staging = temporary_path / "tafsir_saadi"
        write_assets(staging, links, pages, quran_map)
        install_staging(staging, args.output.resolve(), args.replace, project_root)
    print("اكتمل استخراج تفسير السعدي وربطه بصفحات المصحف محليًا.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"خطأ: {error}", file=sys.stderr)
        raise SystemExit(1)
