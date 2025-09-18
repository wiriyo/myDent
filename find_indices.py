from pathlib import Path
text = Path(r"lib/widgets/appointment_detail_dialog.dart").read_text(encoding="utf-8")
start_str = "            Row(\n              crossAxisAlignment: CrossAxisAlignment.center,\n              children: [\n                Image.asset(AppTheme.iconPathUser, width: 24, height: 24),\n                const SizedBox(width: 12),\n                Expanded(\n                  child: Text(\n                    patientName,\n                    style: const TextStyle(\n                      fontSize: 22,\n                      fontWeight: FontWeight.bold,\n                      color: Color(0xFF6A4DBA),\n                      fontFamily: AppTheme.fontFamily,\n                    ),\n                  ),\n                ),\n              ],\n            ),\n            const SizedBox(height: 8),\n            Row(\n              children: [\n                Text("
start = text.find(start_str)
print('start', start)
end_str = "            const SizedBox(height: 16),\n            Row(\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                Image.asset(\n                  'assets/icons/treatment.png',"
end = text.find(end_str, start)
print('end', end)
