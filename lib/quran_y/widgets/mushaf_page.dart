import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../repositories/mushaf_repository.dart';

class MushafPage extends StatelessWidget {
  const MushafPage({
    required this.pageNumber,
    required this.darkMode,
    this.repository = const MushafRepository(),
    super.key,
  });

  final int pageNumber;
  final bool darkMode;
  final MushafRepository repository;

  @override
  Widget build(BuildContext context) {
    final assetPath = repository.pageAssetPath(pageNumber);
    final isOpeningSpread = pageNumber <= 2;
    final pageImage = ColorFiltered(
      colorFilter: darkMode
          ? const ColorFilter.matrix(<double>[
              -0.1106,
              -0.3719,
              -0.0375,
              0,
              196,
              -0.1169,
              -0.3934,
              -0.0397,
              0,
              216,
              -0.1127,
              -0.3791,
              -0.0383,
              0,
              204,
              0,
              0,
              0,
              1,
              0,
            ])
          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: _CroppedMushafImage(assetPath: assetPath, pageNumber: pageNumber),
    );

    return ColoredBox(
      color: darkMode ? Colors.black : Colors.white,
      child: SizedBox.expand(
        child: isOpeningSpread
            ? pageImage
            : Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 8,
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: ClipRect(child: pageImage),
              ),
      ),
    );
  }
}

class _CroppedMushafImage extends StatefulWidget {
  const _CroppedMushafImage({
    required this.assetPath,
    required this.pageNumber,
  });

  final String assetPath;
  final int pageNumber;

  @override
  State<_CroppedMushafImage> createState() => _CroppedMushafImageState();
}

class _CroppedMushafImageState extends State<_CroppedMushafImage> {
  // الصورتان الافتتاحيتان محفوظتان داخل لوح أبيض كبير. هذه الحدود تلتقط
  // التصميم الأخضر كاملًا من دون قص العنوان أو أي آية.
  static const double _openingLeftFraction = 0.2195;
  static const double _openingTopFraction = 0.226;
  static const double _openingWidthFraction = 0.558;
  static const double _openingHeightFraction = 0.549;

  // المتن مزاح إلى اليسار في الصفحات الفردية وإلى اليمين في الزوجية.
  // النافذتان أدناه لهما العرض نفسه وتستبعدان الهامش الخارجي وعلامة الحزب.
  // الصفحتان 1 و2 تستخدمان حدود التصميم الافتتاحي أعلاه بدل هذه النافذة.
  static const double _oddPageLeftFraction = 0.055;
  static const double _evenPageLeftFraction = 0.175;
  static const double _pageWidthFraction = 0.77;

  ImageStream? _stream;
  ImageInfo? _imageInfo;
  Object? _error;

  late final ImageStreamListener _listener = ImageStreamListener(
    _handleImage,
    onError: _handleError,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _CroppedMushafImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _resolveImage();
  }

  void _resolveImage() {
    final nextStream = AssetImage(
      widget.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == nextStream.key) return;
    _stream?.removeListener(_listener);
    _imageInfo?.dispose();
    _imageInfo = null;
    _error = null;
    _stream = nextStream..addListener(_listener);
  }

  void _handleImage(ImageInfo imageInfo, bool synchronousCall) {
    if (!mounted) {
      imageInfo.dispose();
      return;
    }
    setState(() {
      _imageInfo?.dispose();
      _imageInfo = imageInfo;
      _error = null;
    });
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() => _error = error);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _MissingPage(pageNumber: widget.pageNumber);
    final image = _imageInfo?.image;
    if (image == null) return const SizedBox.expand();

    final isOpeningSpread = widget.pageNumber <= 2;

    return CustomPaint(
      size: Size.infinite,
      painter: _CroppedMushafPainter(
        image: image,
        sourceLeftFraction: isOpeningSpread
            ? _openingLeftFraction
            : widget.pageNumber.isOdd
            ? _oddPageLeftFraction
            : _evenPageLeftFraction,
        sourceTopFraction: isOpeningSpread ? _openingTopFraction : 0,
        sourceWidthFraction: isOpeningSpread
            ? _openingWidthFraction
            : _pageWidthFraction,
        sourceHeightFraction: isOpeningSpread ? _openingHeightFraction : 1,
        // الصفحتان الافتتاحيتان لهما تصميم دائري خاص؛ لذلك تُعرضان
        // بنسبة الصورة الأصلية بلا أي ضغط أو تمديد رأسي.
        verticalDisplayScale: isOpeningSpread ? 1 : 1.18,
      ),
    );
  }
}

class _CroppedMushafPainter extends CustomPainter {
  const _CroppedMushafPainter({
    required this.image,
    required this.sourceLeftFraction,
    required this.sourceTopFraction,
    required this.sourceWidthFraction,
    required this.sourceHeightFraction,
    required this.verticalDisplayScale,
  });

  final ui.Image image;
  final double sourceLeftFraction;
  final double sourceTopFraction;
  final double sourceWidthFraction;
  final double sourceHeightFraction;
  final double verticalDisplayScale;

  @override
  void paint(Canvas canvas, Size size) {
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final source = Rect.fromLTWH(
      imageWidth * sourceLeftFraction,
      imageHeight * sourceTopFraction,
      imageWidth * sourceWidthFraction,
      imageHeight * sourceHeightFraction,
    );
    final fitted = applyBoxFit(BoxFit.contain, source.size, size);
    final containedDestination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final destination = Rect.fromCenter(
      center: containedDestination.center,
      width: containedDestination.width,
      height: containedDestination.height * verticalDisplayScale,
    );

    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _CroppedMushafPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.sourceLeftFraction != sourceLeftFraction ||
      oldDelegate.sourceTopFraction != sourceTopFraction ||
      oldDelegate.sourceWidthFraction != sourceWidthFraction ||
      oldDelegate.sourceHeightFraction != sourceHeightFraction ||
      oldDelegate.verticalDisplayScale != verticalDisplayScale;
}

class _MissingPage extends StatelessWidget {
  const _MissingPage({required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'صفحة المصحف $pageNumber غير متوفرة بعد',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'صفحة $pageNumber',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'ستظهر هنا بعد تجهيز صفحات مصحف المدينة.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
