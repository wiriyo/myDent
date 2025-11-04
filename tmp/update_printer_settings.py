from pathlib import Path
import re

path = Path(r"lib/features/printing/render/printer_settings_page.dart")
text = path.read_text(encoding="utf-8")

pattern = re.compile(r"  Future<void> _captureAndSavePng\(\) async \{[\s\S]*?\n  \}")
match = pattern.search(text)
if not match:
    raise SystemExit('capture block not found')
block_start = match.start()
comment_start = text.rfind('\n', 0, block_start - 1) + 1
comment_end = block_start
comment_line = text[comment_start:comment_end].rstrip('\n')
if not comment_line.strip().startswith('//'):
    raise SystemExit('comment line not found')
old_segment = text[comment_start:match.end()]

new_segment = (
    f"{comment_line}\n"
    "  Future<Uint8List?> _ensurePng({bool forceRecapture = false}) async {\n"
    "    if (forceRecapture) {\n"
    "      _cachedPngBase64 = null;\n"
    "      _lastPng = null;\n"
    "    }\n"
    "    if (_lastPng != null) {\n"
    "      _cachedPngBase64 ??= base64Encode(_lastPng!);\n"
    "      return _lastPng;\n"
    "    }\n\n"
    "    final renderObject = _boundaryKey.currentContext?.findRenderObject();\n"
    "    if (renderObject is! RenderRepaintBoundary) {\n"
    "      return null;\n"
    "    }\n\n"
    "    final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);\n"
    "    try {\n"
    "      final ByteData? byteData = await image.toByteData(\n"
    "        format: ui.ImageByteFormat.png,\n"
    "      );\n"
    "      if (byteData == null) {\n"
    "        return null;\n"
    "      }\n\n"
    "      final Uint8List raw = byteData.buffer.asUint8List();\n"
    "      _lastPng = await ThermalPngPostProcessor.process(\n"
    "        raw,\n"
    "        targetWidth: _browserPixelWidth,\n"
    "      );\n"
    "      _cachedPngBase64 = base64Encode(_lastPng!);\n"
    "      return _lastPng;\n"
    "    } finally {\n"
    "      image.dispose();\n"
    "    }\n"
    "  }\n\n"
    "  Future<void> _captureAndSavePng() async {\n"
    "    if (_busyCapture) return;\n"
    "    setState(() => _busyCapture = true);\n"
    "    try {\n"
    "      final png = await _ensurePng(forceRecapture: true);\n"
    "      if (png == null) {\n"
    "        throw Exception('????? RepaintBoundary');\n"
    "      }\n\n"
    "      final fileName =\n"
    "          'MyDent-TestPrint-${DateTime.now().millisecondsSinceEpoch}.png';\n"
    "      final bool success = await ImageSaverService.saveImage(\n"
    "        png,\n"
    "        fileName,\n"
    "      );\n\n"
    "      if (!mounted) return;\n\n"
    "      if (success) {\n"
    "        _showSnackBarSafe(\n"
    "          const SnackBar(\n"
    "            content: Text('??????????????????????????????????????'),\n"
    "          ),\n"
    "        );\n"
    "      } else {\n"
    "        _showSnackBarSafe(\n"
    "          const SnackBar(\n"
    "            content: Text('??????????????????! ????????????????????'),\n"
    "          ),\n"
    "        );\n"
    "      }\n"
    "    } catch (e) {\n"
    "      if (mounted) {\n"
    "        _showSnackBarSafe(\n"
    "          SnackBar(content: Text('??????????????: $e')),\n"
    "        );\n"
    "      }\n"
    "    } finally {\n"
    "      if (mounted) setState(() => _busyCapture = false);\n"
    "    }\n"
    "  }\n"
)

text = text.replace(old_segment, new_segment, 1)
path.write_text(text, encoding="utf-8")
