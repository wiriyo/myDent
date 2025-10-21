import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

class ThermalPngPostProcessor {
  const ThermalPngPostProcessor._();

  static const int defaultTargetWidth = 576;
  static const int defaultMaxBytes = 300000;
  static const int _minWidth = 384;
  static const int _maxAttempts = 4;

  static Future<Uint8List> process(
    Uint8List input, {
    int targetWidth = defaultTargetWidth,
    int maxBytes = defaultMaxBytes,
  }) async {
    try {
      final ui.Image baseImage = await _decodeImage(input);
      try {
        final int sourceWidth = baseImage.width;
        final int sourceHeight = baseImage.height;
        if (sourceWidth <= 0 || sourceHeight <= 0) {
          return input;
        }

        int desiredWidth = math.min(targetWidth, sourceWidth);
        if (desiredWidth <= 0) {
          desiredWidth = sourceWidth;
        }

        Uint8List? lastBytes;
        for (int attempt = 0; attempt < _maxAttempts; attempt += 1) {
          final _RenderResult result = await _renderImage(
            baseImage,
            desiredWidth,
          );
          lastBytes = result.bytes;
          if (lastBytes.lengthInBytes <= maxBytes || desiredWidth <= _minWidth) {
            break;
          }

          final int nextWidth = math.max(
            _minWidth,
            (desiredWidth * 0.9).round(),
          );
          if (nextWidth >= desiredWidth) {
            break;
          }
          desiredWidth = nextWidth;
        }

        return lastBytes ?? input;
      } finally {
        baseImage.dispose();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ThermalPngPostProcessor failed: $error\n$stackTrace');
      }
      return input;
    }
  }

  static Future<_RenderResult> _renderImage(ui.Image baseImage, int targetWidth) async {
    final int sourceWidth = baseImage.width;
    final int sourceHeight = baseImage.height;
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return _RenderResult(bytes: Uint8List.fromList(const []), width: 0, height: 0);
    }

    final double scale = targetWidth / sourceWidth;
    final int targetHeight = math.max(1, (sourceHeight * scale).round());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    canvas.scale(scale, scale);
    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

    final ui.Image rendered = await recorder
        .endRecording()
        .toImage(targetWidth, targetHeight);
    try {
      final ByteData? pngBytes = await rendered.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (pngBytes == null) {
        return _RenderResult(bytes: Uint8List.fromList(const []), width: targetWidth, height: targetHeight);
      }
      return _RenderResult(
        bytes: pngBytes.buffer.asUint8List(),
        width: targetWidth,
        height: targetHeight,
      );
    } finally {
      rendered.dispose();
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(buffer);
    final ui.Codec codec = await descriptor.instantiateCodec();
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

class _RenderResult {
  const _RenderResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
