import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenshotService {
  static final ScreenshotService _instance = ScreenshotService._internal();
  factory ScreenshotService() => _instance;
  ScreenshotService._internal();

  final GlobalKey _globalKey = GlobalKey();

  /// Put this in your MaterialApp (root level)
  GlobalKey get globalKey => _globalKey;

  /// Call this from anywhere to capture current screen
  Future<String?> captureCurrentScreen({
    double pixelRatio = 2.0,
    String? customFileName,
  }) async {
    try {
      if (!await _requestStoragePermission()) {
        debugPrint("Permission denied");
        return null;
      }

      if (_globalKey.currentContext == null) {
        debugPrint("Screenshot failed: currentContext is null. Ensure GlobalKey is attached to a RepaintBoundary.");
        return null;
      }
      
      final renderObject = _globalKey.currentContext!.findRenderObject();
      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        debugPrint("Screenshot failed: RenderRepaintBoundary not found.");
        return null;
      }

      if (renderObject.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint("Screenshot failed: byteData is null.");
        return null;
      }
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to app's documents folder
      final directory = await getTemporaryDirectory();
      final String fileName = customFileName ?? 
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final String filePath = '${directory.path}/$fileName';

      final File file = File(filePath);
      await file.writeAsBytes(pngBytes);

      return filePath;
    } catch (e) {
      debugPrint('Screenshot failed: $e');
      return null;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.photos.request().isGranted) return true; 
      return (await Permission.storage.request()).isGranted;
    } else if (Platform.isIOS) {
      return (await Permission.photos.request()).isGranted;
    }
    return true;
  }
}