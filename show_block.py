from pathlib import Path
text = Path(r"lib/widgets/appointment_detail_dialog.dart").read_text(encoding="utf-8")
start = text.index("            Row(\n              crossAxisAlignment: CrossAxisAlignment.center,\n              children: [\n                Image.asset(AppTheme.iconPathUser, width: 24, height: 24)")
end = text.index("            Row(\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                Image.asset('assets/icons/treatment.png', width: 40, height: 40)", start)
block = text[start:end]
print(block)
print('\n---\n', len(block))
