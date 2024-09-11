import 'package:opencv_dart/core.dart';

extension SizeToString on Size {
  String get string => '($width x $height)';
}

extension PointToString on Point {
  String get string => '($x, $y)';
}

extension RectPoints on Rect {
  Point get leftTop => Point(x, y);
  Point get rightBottom => Point(right, bottom);
  Size get size => Size(width, height);
}
