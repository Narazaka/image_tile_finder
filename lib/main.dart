import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';
import "process_tile.dart";
import 'image_region.dart';
import 'image_texture.dart';
import 'util.dart';

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
  ImageMat? _source;
  ImageMat? _result;
  ImageRegion _imageRegion = ImageRegion.zero();
  double _resultFrac = 0.0;
  Uint8List? _encodedResultTiledImage;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _source?.dispose();
    _result?.dispose();
    super.dispose();
  }

  @override
  void onWindowResize() {
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    setState(() {
      _imageRegion = _imageRegion.setViewSize(imageViewSize);
    });
  }

  void _onDragDone(DropDoneDetails details) async {
    var path = details.files.first.path;
    var tex = await ImageMat.readAsync(path);
    if (tex == null) {
      setState(() {
        _source?.dispose();
        _source = null;
        _imageRegion = ImageRegion.zero();
      });
      return;
    }
    setState(() {
      _sourcePath = path;
      _source?.dispose();
      _source = tex;
      _imageRegion = ImageRegion.zero().setSourceImageSize(tex.size);
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
      _imageRegion = _imageRegion
          .setViewSize(imageViewSize)
          .setStartOffsetRate(offsetRate)
          .setEndOffsetRate(offsetRate);
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
      _imageRegion = _imageRegion.setViewSize(imageViewSize).setEndOffsetRate(
          _getImageOffset(event.localPosition, imageViewSize));
    });
  }

  void _onClickImageEnd(PointerUpEvent event) {
    var imageViewSize = _getImageViewSize();
    if (imageViewSize == Size.zero) {
      return;
    }
    setState(() {
      _dragging = false;
      _imageRegion = _imageRegion.setViewSize(imageViewSize).setEndOffsetRate(
          _getImageOffset(event.localPosition, imageViewSize));
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
    if (_result == null) {
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
    _result!.save(dest);
  }

  void _onStartDetect() async {
    if (_source == null) {
      return;
    }
    if (_imageRegion.image.width == 0 || _imageRegion.image.height == 0) {
      return;
    }
    var (resultMat, frac) =
        ProcessTile().getTile(_source!.mat.region(_imageRegion.image));
    if (resultMat == null) {
      return;
    }
    final result = await ImageMat.fromMat(resultMat);
    var tiled = cv.repeat(resultMat, 2, 2);
    var (successTiled, encodedTiled) = await cv.imencodeAsync(".png", tiled);
    tiled.dispose();
    setState(() {
      _resultFrac = frac;
      _result?.dispose();
      _result = result;
      _encodedResultTiledImage = encodedTiled;
    });
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
                          _source == null
                              ? const Text("no image")
                              : Image.memory(
                                  key: _imageContainerKey, _source!.encoded),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: PaintRect(_imageRegion.view, Colors.red),
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
                  Text("image size ${_source?.size.string}"),
                  Text(
                      "${_imageRegion.image.leftTop.string} - ${_imageRegion.image.rightBottom.string} / ${_imageRegion.image.size.string}"),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary),
                      onPressed: _onStartDetect,
                      child: const Text("do")),
                  Container(
                    child: _result == null
                        ? const Text("no image")
                        : Image.memory(_result!.encoded),
                  ),
                  _result == null || _source == null
                      ? const SizedBox(width: 1, height: 1)
                      : Column(children: [
                          Text(_result!.size.string),
                          const Text("tiling:"),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "X",
                                ),
                                controller: TextEditingController(
                                    text: (_source!.size.width /
                                            _result!.size.width)
                                        .toString())),
                          ),
                          SizedBox(
                              width: 100,
                              child: TextFormField(
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Y",
                                  ),
                                  controller: TextEditingController(
                                      text: (_source!.size.height /
                                              _result!.size.height)
                                          .toString()))),
                        ]),
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
