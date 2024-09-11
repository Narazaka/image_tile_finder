import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_dart/core.dart';

class ImageMat {
  static Future<ImageMat?> readAsync(String path) async {
    final mat = await cv.imreadAsync(path);
    if (mat.isEmpty) {
      return null;
    }
    return fromMat(mat);
  }

  static Future<ImageMat?> fromMat(Mat mat) async {
    final (success, encoded) = await cv.imencodeAsync('.png', mat);
    return ImageMat(mat, encoded);
  }

  Mat mat;
  Uint8List encoded;
  ImageMat(this.mat, this.encoded);
  Size get size => Size(mat.shape[1], mat.shape[0]);

  void save(String path) async {
    await cv.imwriteAsync(path, mat);
  }

  void dispose() {
    mat.dispose();
  }
}
