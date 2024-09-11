import 'dart:ui';
import 'package:opencv_dart/core.dart' as cvcore;

class ImageRegion {
  static ImageRegion zero() {
    return ImageRegion(
        sourceImageSize: cvcore.Size(0, 0),
        viewSize: const Size(0, 0),
        startOffsetRate: const Offset(0, 0),
        endOffsetRate: const Offset(0, 0));
  }

  final cvcore.Size sourceImageSize;
  final Size viewSize;
  final Offset startOffsetRate;
  final Offset endOffsetRate;

  late final Rect rate;
  late final Rect view;
  late final cvcore.Rect image;

  ImageRegion(
      {required this.sourceImageSize,
      required this.viewSize,
      required this.startOffsetRate,
      required this.endOffsetRate}) {
    rate = Rect.fromLTWH(
        startOffsetRate.dx < endOffsetRate.dx
            ? startOffsetRate.dx
            : endOffsetRate.dx,
        startOffsetRate.dy < endOffsetRate.dy
            ? startOffsetRate.dy
            : endOffsetRate.dy,
        (startOffsetRate.dx - endOffsetRate.dx).abs(),
        (startOffsetRate.dy - endOffsetRate.dy).abs());
    view = Rect.fromLTWH(rate.left * viewSize.width, rate.top * viewSize.height,
        rate.width * viewSize.width, rate.height * viewSize.height);
    image = cvcore.Rect(
        (rate.left * sourceImageSize.width).floor(),
        (rate.top * sourceImageSize.height).floor(),
        (rate.width * sourceImageSize.width).round(),
        (rate.height * sourceImageSize.height).round());
  }

  ImageRegion setSourceImageSize(cvcore.Size sourceImageSize) {
    return ImageRegion(
        sourceImageSize: sourceImageSize,
        viewSize: viewSize,
        startOffsetRate: startOffsetRate,
        endOffsetRate: endOffsetRate);
  }

  ImageRegion setViewSize(Size viewSize) {
    return ImageRegion(
        sourceImageSize: sourceImageSize,
        viewSize: viewSize,
        startOffsetRate: startOffsetRate,
        endOffsetRate: endOffsetRate);
  }

  ImageRegion setStartOffsetRate(Offset startOffsetRate) {
    return ImageRegion(
        sourceImageSize: sourceImageSize,
        viewSize: viewSize,
        startOffsetRate: startOffsetRate,
        endOffsetRate: endOffsetRate);
  }

  ImageRegion setEndOffsetRate(Offset endOffsetRate) {
    return ImageRegion(
        sourceImageSize: sourceImageSize,
        viewSize: viewSize,
        startOffsetRate: startOffsetRate,
        endOffsetRate: endOffsetRate);
  }
}
