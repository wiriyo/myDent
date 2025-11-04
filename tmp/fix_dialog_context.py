from pathlib import Path
import re

path = Path(r"lib/features/printing/render/printer_settings_page.dart")
text = path.read_text(encoding="utf-8")

text = text.replace(
    "                Navigator.of(dialogContext).pop(true);",
    "                Navigator.of(context).pop(true);",
)
text = text.replace(
    "                Navigator.of(dialogContext).pop(opened);",
    "                Navigator.of(context).pop(opened);",
)

path.write_text(text, encoding="utf-8")
