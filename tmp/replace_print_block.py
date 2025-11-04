from pathlib import Path
import re

path = Path(r"lib/features/printing/render/printer_settings_page.dart")
text = path.read_text(encoding="utf-8")

pattern = re.compile(r"  Future<void> _print\(\) async \{[\s\S]*?\n  \}")
match = pattern.search(text)
if not match:
    raise SystemExit('print block not found')
old_block = match.group(0)

new_block = (
    "  Future<void> _print() async {\n"
    "    if (_busyCapture) return;\n"
    "    if (kIsWeb) {\n"
    "      await _printWeb();\n"
    "      return;\n"
    "    }\n\n"
    "    setState(() => _busyCapture = true);\n\n"
    "    final messenger = ScaffoldMessenger.of(context);\n\n"
    "    try {\n"
    "      final png = await _ensurePng();\n"
    "      if (png == null) {\n"
    "        if (!mounted) return;\n"
    "        messenger.showSnackBar(\n"
    "          const SnackBar(content: Text('????????????????????????????????')),\n"
    "        );\n"
    "        return;\n"
    "      }\n\n"
    "      final fileName =\n"
    "          'MyDent-PrinterSample-${DateTime.now().millisecondsSinceEpoch}.png';\n"
    "      final saved = await ImageSaverService.saveImage(png, fileName);\n"
    "      if (!saved) {\n"
    "        if (!mounted) return;\n"
    "        messenger.showSnackBar(\n"
    "          const SnackBar(\n"
    "            content: Text(\n"
    "              '?????????????????????????????????????????? ???????????????????????????????????',\n"
    "            ),\n"
    "          ),\n"
    "        );\n"
    "        return;\n"
    "      }\n\n"
    "      if (!mounted) return;\n    "
    "      final int feedLines = PrintSettings.feedLinesFromSetting(\n"
    "        _printingPostFeed,\n"
    "      );\n    "
    "      await ThermalPrinterService.I.ensureConnectAndPrintPng(\n"
    "        context,\n"
    "        png,\n"
    "        feed: feedLines,\n"
    "        cut: true,\n"
    "      );\n    "
    "      if (!mounted) return;\n    "
    "      messenger.showSnackBar(\n"
    "        const SnackBar(content: Text('??????????????????????????')),\n"
    "      );\n"
    "    } catch (e) {\n"
    "      if (!mounted) return;\n"
    "      messenger.showSnackBar(\n"
    "        SnackBar(content: Text('?????????????????????????????: $e')),\n"
    "      );\n"
    "    } finally {\n"
    "      if (mounted) {\n"
    "        setState(() => _busyCapture = false);\n"
    "      }\n"
    "    }\n"
    "  }"
)

text = text.replace(old_block, new_block, 1)
path.write_text(text, encoding="utf-8")
