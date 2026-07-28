#!/bin/bash
# يحوّل الـ604 ملف .ai (نسخة 1441 من مجمع الملك فهد) إلى صور JPG
# بنفس ترقيم صفحات المصحف (1.jpg .. 604.jpg)، لضمان استخدام نسخة رسمية واحدة
# فقط بدون خلطها بأي مصدر آخر.
#
# يستخدم qlmanage (أداة macOS مدمجة لعرض Quick Look) بدل sips لأنه يعطي
# دقة أعلى بكثير عند رسم ملفات PDF/AI (نطلب هنا 2400 بكسل للضلع الأطول
# بدل ~1520 بكسل التي كانت تنتج سابقًا)، فتصبح الآيات أوضح بدون تشويش
# عند التكبير داخل التطبيق، مع بقاء المصدر نفسه (لا خلط إصدارات).
#
# شغّله من الطرفية (Terminal) على جهازك بعد ضبط SRC أدناه.
set -e

SRC="$HOME/Desktop/القرآن الكريم/1441 مصحف حفص-إليستريتور"
OUT="$HOME/Desktop/quran_mushaf_pages_official"
TMP="$(mktemp -d)"
mkdir -p "$OUT"

# الضلع الأطول للصورة الناتجة بالبكسل (كلما زاد الرقم زادت الدقة والوضوح
# عند التكبير، لكن يزيد حجم ملف كل صورة). 2400 يعطي دقة ممتازة لكل الشاشات.
QUALITY_SIZE=2400

ok=0
fail=0

for f in "$SRC"/*___Hafs39__DM.ai; do
  base=$(basename "$f")
  num=$(echo "$base" | sed 's/___Hafs39__DM\.ai$//' | sed 's/^0*//')

  # sips لا يتعرف على صيغة .ai رغم أن محتواها PDF فعليًا، لذلك ننسخها
  # مؤقتًا بامتداد .pdf ليتعرف عليها بشكل صحيح.
  cp "$f" "$TMP/page.pdf"

  rm -f "$TMP/page.pdf.png"
  if qlmanage -t -s "$QUALITY_SIZE" -o "$TMP" "$TMP/page.pdf" >/dev/null 2>&1 \
      && [ -f "$TMP/page.pdf.png" ] \
      && sips -s format jpeg -s formatOptions best "$TMP/page.pdf.png" --out "$OUT/$num.jpg" >/dev/null 2>&1; then
    ok=$((ok+1))
    echo "تم (جودة عالية): صفحة $num"
  else
    # خط رجوع احتياطي: لو فشل qlmanage لأي سبب نستخدم sips كما كان سابقًا
    if sips -s format jpeg "$TMP/page.pdf" --out "$OUT/$num.jpg" >/dev/null 2>&1; then
      ok=$((ok+1))
      echo "تم (جودة عادية - fallback): صفحة $num"
    else
      fail=$((fail+1))
      echo "فشل: صفحة $num"
    fi
  fi
  rm -f "$TMP/page.pdf" "$TMP/page.pdf.png"
done

rm -rf "$TMP"

echo "----------------------------------"
echo "انتهى! نجح: $ok، فشل: $fail"
echo "الصور في: $OUT"
echo "عدد الصور الفعلي: $(ls "$OUT"/*.jpg 2>/dev/null | wc -l)"
