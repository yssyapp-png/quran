#!/bin/bash
# يضبط اسم التطبيق الظاهر تحت الأيقونة إلى "القرآن الكريم"
# شغّله بعد تنفيذ: flutter create .
set -e

APP_NAME="القرآن الكريم"

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  sed -i.bak -E "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" "$MANIFEST"
  rm -f "$MANIFEST.bak"
  echo "✅ تم تحديث اسم التطبيق في Android: $MANIFEST"
else
  echo "⚠️  لم يتم العثور على $MANIFEST — تأكد من تنفيذ 'flutter create .' أولاً"
fi

PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  if grep -q "CFBundleDisplayName" "$PLIST"; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST" 2>/dev/null || \
    sed -i.bak -E "0,/<key>CFBundleDisplayName<\/key>/{n;s/<string>.*<\/string>/<string>$APP_NAME<\/string>/}" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$PLIST" 2>/dev/null || \
    sed -i.bak "s/<key>CFBundleName<\/key>/<key>CFBundleDisplayName<\/key><string>$APP_NAME<\/string><key>CFBundleName<\/key>/" "$PLIST"
  fi
  rm -f "$PLIST.bak"
  echo "✅ تم تحديث اسم التطبيق في iOS: $PLIST"
else
  echo "⚠️  لم يتم العثور على $PLIST — تأكد من تنفيذ 'flutter create .' أولاً"
fi

echo "تم الانتهاء. اسم التطبيق الآن: $APP_NAME"

echo "جاري توليد أيقونة التطبيق من assets/icon/app_icon.png ..."
flutter pub get
dart run flutter_launcher_icons
echo "✅ تم توليد أيقونة التطبيق لكل المنصات"
