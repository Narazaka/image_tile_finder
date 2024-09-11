import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_dart/core.dart' as cvcore;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  final GlobalKey _imageContainerKey = GlobalKey();

  bool _dragging = false;
  String? _sourcePath;
  cvcore.Mat? _sourceMat;
  Uint8List? _encodedSourceImage;
  cvcore.Size _imageSize = cvcore.Size(0, 0);
  Offset _startOffsetRate = Offset.zero;
  Offset _endOffsetRate = Offset.zero;
  Size _imageViewSize = Size.zero;
  double _resultFrac = 0.0;
  cvcore.Mat? _resultMat;
  Uint8List? _encodedResultImage;
  Uint8List? _encodedResultTiledImage;

  double get _leftOffsetRate => _startOffsetRate.dx < _endOffsetRate.dx
      ? _startOffsetRate.dx
      : _endOffsetRate.dx;
  double get _topOffsetRate => _startOffsetRate.dy < _endOffsetRate.dy
      ? _startOffsetRate.dy
      : _endOffsetRate.dy;
  double get _widthRate => (_startOffsetRate.dx - _endOffsetRate.dx).abs();
  double get _heightRate => (_startOffsetRate.dy - _endOffsetRate.dy).abs();
  cvcore.Size get _leftTopOffset => cvcore.Size(
      (_leftOffsetRate * _imageSize.width).floor(),
      (_topOffsetRate * _imageSize.height).floor());
  cvcore.Size get _size => cvcore.Size((_widthRate * _imageSize.width).round(),
      (_heightRate * _imageSize.height).round());
  cvcore.Size get _rightBottomOffset => cvcore.Size(
      _leftTopOffset.width + _size.width, _leftTopOffset.height + _size.height);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() {
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    setState(() {
      _imageViewSize = imageViewSize;
    });
  }

  void _onDragDone(DropDoneDetails details) async {
    var path = details.files.first.path;
    var mat = await cv.imreadAsync(path);
    if (mat.isEmpty) {
      setState(() {
        _sourceMat = null;
        _encodedSourceImage = null;
        _imageSize = cvcore.Size(0, 0);
      });
      return;
    }
    var (success, encoded) = await cv.imencodeAsync(".png", mat);
    setState(() {
      _sourcePath = path;
      _sourceMat = mat;
      _encodedSourceImage = encoded;
      _imageSize = cvcore.Size(mat.shape[1], mat.shape[0]);
    });
  }

  void _onClickImageStart(PointerDownEvent event) {
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    final offsetRate = _getImageOffset(event.localPosition, imageViewSize);
    setState(() {
      _dragging = true;
      _imageViewSize = imageViewSize;
      _startOffsetRate = offsetRate;
      _endOffsetRate = offsetRate;
    });
  }

  void _onClickImageDrag(PointerMoveEvent event) {
    if (!_dragging) {
      return;
    }
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    setState(() {
      _imageViewSize = imageViewSize;
      _endOffsetRate = _getImageOffset(event.localPosition, imageViewSize);
    });
  }

  void _onClickImageEnd(PointerUpEvent event) {
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    setState(() {
      _dragging = false;
      _imageViewSize = imageViewSize;
      _endOffsetRate = _getImageOffset(event.localPosition, imageViewSize);
    });
  }

  Offset _getImageOffset(Offset localPosition, Size imageViewSize) {
    return Offset(localPosition.dx / imageViewSize.width,
        localPosition.dy / imageViewSize.height);
  }

  Size _getImageViewSize() {
    final renderBox =
        _imageContainerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return Size.zero;
    }
    return renderBox.size;
  }

  void _onSave() async {
    if (_resultMat == null) {
      return;
    }
    final dest = await FilePicker.platform.saveFile(
        fileName: _sourcePath == null
            ? "result.png"
            : "${path.basenameWithoutExtension(_sourcePath!)}_tiled${path.extension(_sourcePath!)}",
        initialDirectory: path.dirname(_sourcePath!),
        type: FileType.image);
    if (dest == null) {
      return;
    }
    cv.imwrite(dest, _resultMat!);
  }

  void _onStartDetect() async {
    if (_sourceMat == null) {
      return;
    }
    var (resultMat, frac) = _getTile(_sourceMat!.region(cv.Rect(
        _leftTopOffset.width,
        _leftTopOffset.height,
        _size.width,
        _size.height)));
    if (resultMat == null) {
      return;
    }
    var (success, encoded) = await cv.imencodeAsync(".png", resultMat);
    var tiled = cv.repeat(resultMat, 2, 2);
    var (successTiled, encodedTiled) = await cv.imencodeAsync(".png", tiled);
    setState(() {
      _resultFrac = frac;
      _resultMat = resultMat;
      _encodedResultImage = encoded;
      _encodedResultTiledImage = encodedTiled;
    });
  }

// cf. https://stackoverflow.com/questions/61940508/find-or-detect-a-single-tile-from-a-tiled-image
  List<(int, int)> _getTileDim(cvcore.Mat im, {maxScan = 512}) {
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
      y0 = max(0, sy0 * 2 - 2);
      y1 = min(h, sy0 * 2 + 2);
    }
    var results = <(int, int)>[];
    for (var y = y0; y < y1; y++) {
      final s = im.region(cvcore.Rect(0, 0, im.shape[1], y));
      var diff = 0;
      for (var yt = y; yt < h; yt += y) {
        final yw = yt + y > h ? h - yt : y;
        final c = im.region(cvcore.Rect(0, yt, im.shape[1], yw));
        final m = min(c.shape[0], s.shape[0]);
        final cr = c.region(cvcore.Rect(0, 0, c.shape[1], m));
        final sr = s.region(cvcore.Rect(0, 0, s.shape[1], m));
        final channelDiff = cv.absDiff(cr, sr).sum();
        diff += _sumScalar(channelDiff).toInt();
      }
      results.add((y, diff));
    }
    results.sort((a, b) => a.$2.compareTo(b.$2));
    return results;
  }

  cvcore.Mat _tile(cvcore.Mat tileSource, cvcore.Mat original) {
    final ny = (original.shape[0] / tileSource.shape[0]).ceil();
    final nx = (original.shape[1] / tileSource.shape[1]).ceil();
    return cv
        .repeat(tileSource, ny, nx)
        .region(cvcore.Rect(0, 0, original.shape[1], original.shape[0]));
  }

  (cvcore.Mat?, double) _getTile(cvcore.Mat im, {eps = 0.005}) {
    final ys = _getTileDim(im);
    final xs = _getTileDim(cv.transpose(im));
    final y = ys.first.$1;
    final x = xs.first.$1;
    final tileIm = im.region(cvcore.Rect(0, 0, x, y));
    final tiled = _tile(tileIm, im);
    final diff = cv.absDiff(tiled, im).mean();
    final frac = _sumScalar(diff) / 4;
    if (frac < eps || true) {
      return (tileIm, frac);
    } else {
      return (null, frac);
    }
  }

  double _sumScalar(cvcore.Scalar scalar) {
    return scalar.val1 + scalar.val2 + scalar.val3 + scalar.val4;
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
        onDragDone: _onDragDone,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(widget.title),
          ),
          body: Center(
              child: Row(children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'source image',
                  ),
                  Listener(
                      onPointerDown: _onClickImageStart,
                      onPointerMove: _onClickImageDrag,
                      onPointerUp: _onClickImageEnd,
                      child: Stack(
                        children: [
                          _encodedSourceImage == null
                              ? const Text("no image")
                              : Image.memory(
                                  key: _imageContainerKey,
                                  _encodedSourceImage!),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PaintRect(
                                  Rect.fromLTWH(
                                      _leftOffsetRate * _imageViewSize.width,
                                      _topOffsetRate * _imageViewSize.height,
                                      _widthRate * _imageViewSize.width,
                                      _heightRate * _imageViewSize.height),
                                  Colors.red),
                            ),
                          )
                        ],
                      ))
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text("detect"),
                  Text("image size ($_imageSize)"),
                  Text(
                      "(${_leftTopOffset.width}, ${_leftTopOffset.height}) - (${_rightBottomOffset.width}, ${_rightBottomOffset.height}) - (${_size.width} x ${_size.height})"),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary),
                      onPressed: _onStartDetect,
                      child: const Text("do")),
                  Container(
                    child: _encodedResultImage == null
                        ? const Text("no image")
                        : Image.memory(_encodedResultImage!),
                  ),
                  Text("${_resultMat?.shape[1]}x${_resultMat?.shape[0]}"),
                  Text("frac: $_resultFrac"),
                  _encodedResultTiledImage == null
                      ? const SizedBox(width: 1, height: 1)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.inversePrimary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary),
                          onPressed: _onSave,
                          child: const Text("save")),
                  const Text("tiled preview"),
                  Container(
                    child: _encodedResultTiledImage == null
                        ? const Text("no tiled")
                        : Image.memory(_encodedResultTiledImage!),
                  ),
                ],
              ),
            )
          ])),
        ));
  }
}

class PaintRect extends CustomPainter {
  PaintRect(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.0;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
