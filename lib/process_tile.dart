import 'dart:math' as math;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_dart/core.dart';

class ProcessTile {
  // cf. https://stackoverflow.com/questions/61940508/find-or-detect-a-single-tile-from-a-tiled-image
  List<(int, int)> _getTileDim(Mat im, {maxScan = 512}) {
    final h = im.shape[0];
    int y0 = 1;
    int y1 = (h * 0.8).floor();
    if (h > maxScan) {
      // doing a kind of pyramid plan since tilability should be invariant of scale.
      var sy0 = _getTileDim(
        cv.resize(im, (0, 0), fx: 0.5, fy: 0.5, interpolation: cv.INTER_AREA),
        maxScan: maxScan,
      ).first.$1;
      if (sy0 == -1) {
        return <(int, int)>[];
      }
      y0 = math.max(0, sy0 * 2 - 2);
      y1 = math.min(h, sy0 * 2 + 2);
    }
    var results = <(int, int)>[];
    for (var y = y0; y < y1; y++) {
      final s = im.region(Rect(0, 0, im.shape[1], y));
      var diff = 0;
      for (var yt = y; yt < h; yt += y) {
        final yw = yt + y > h ? h - yt : y;
        final c = im.region(Rect(0, yt, im.shape[1], yw));
        final m = math.min(c.shape[0], s.shape[0]);
        final cr = c.region(Rect(0, 0, c.shape[1], m));
        final sr = s.region(Rect(0, 0, s.shape[1], m));
        final channelDiff = cv.absDiff(cr, sr).sum();
        diff += _sumScalar(channelDiff).toInt();
      }
      results.add((y, diff));
    }
    results.sort((a, b) => a.$2.compareTo(b.$2));
    return results;
  }

  Mat _tile(Mat tileSource, Mat original) {
    final ny = (original.shape[0] / tileSource.shape[0]).ceil();
    final nx = (original.shape[1] / tileSource.shape[1]).ceil();
    return cv
        .repeat(tileSource, ny, nx)
        .region(Rect(0, 0, original.shape[1], original.shape[0]));
  }

  (Mat?, double) getTile(Mat im) {
    final ys = _getTileDim(im);
    final xs = _getTileDim(cv.transpose(im));
    final y = ys.first.$1;
    final x = xs.first.$1;
    final tileIm = im.region(Rect(0, 0, x, y));
    final tiled = _tile(tileIm, im);
    final diff = cv.absDiff(tiled, im).mean();
    final frac = _sumScalar(diff) / 4;
    return (tileIm, frac);
  }

  double _sumScalar(Scalar scalar) {
    return scalar.val1 + scalar.val2 + scalar.val3 + scalar.val4;
  }
}
