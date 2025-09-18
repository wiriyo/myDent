from pathlib import Path
text = Path(r"lib/screens/patient_add.dart").read_text(encoding='utf-8')
text = text.replace("return ['หญิง', 'ชาย', 'อื่นๆ'].map((String value) {", "return ['ไม่ระบุ', 'ชาย', 'หญิง'].map((String value) {")
text = text.replace("['หญิง', 'ชาย', 'อื่นๆ'].map((String value) {", "['ไม่ระบุ', 'ชาย', 'หญิง'].map((String value) {")
Path(r"lib/screens/patient_add.dart").write_text(text, encoding='utf-8')
