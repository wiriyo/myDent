from pathlib import Path

path = Path(r"lib/features/printing/render/printer_settings_page.dart")
text = path.read_text(encoding="utf-8")
marker = "class _CombinedSlipWidget extends StatelessWidget"
index = text.find(marker)
if index == -1:
    raise SystemExit('combined widget marker not found')

insert_text = """

class _PrinterChoice {
  const _PrinterChoice({required this.printerName, required this.remember});

  final String? printerName;
  final bool remember;
}
"""

text = text[:index] + insert_text + text[index:]
path.write_text(text, encoding="utf-8")
