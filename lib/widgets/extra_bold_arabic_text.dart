import 'package:flutter/material.dart';

/// نص عربي "فائق السماكة": يرسم طبقة تحتية بحدّ (stroke) رفيع خلف النص
/// المعبّأ العادي، فتبدو الحروف أثخن بصريًا (تقارب زيادة سماكة 15%) دون
/// الحاجة لملف خط بوزن Extra Bold فعلي — مفيد مع خطوط عثمانية أحادية الوزن
/// مثل HafsSmart التي لا توفر أوزانًا متعددة.
class ExtraBoldArabicText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final double strokeWidth;

  const ExtraBoldArabicText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.strokeWidth = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    // سماكة صفر أو أقل تعني "بدون طبقة حدّ إضافية" (مستوى عادي أو عريض
    // فقط) — نتجنب رسم طبقة Stack زائدة لا داعي لها في هذه الحالة.
    if (strokeWidth <= 0) {
      return Text(text, textAlign: textAlign, style: style);
    }
    final strokeColor = style.color ?? Colors.black;
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, textAlign: textAlign, style: style),
      ],
    );
  }
}
