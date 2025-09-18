from pathlib import Path
text = Path(r"lib/screens/patient_add.dart").read_text(encoding='utf-8')
text = text.replace("case 'หญิง':", "case 'หญิง':")
text = text.replace("case 'ชาย':", "case 'ชาย':")
text = text.replace("default:\n        newGender = 'อื่นๆ';", "default:\n        newGender = 'ไม่ระบุ';")
Path(r"lib/screens/patient_add.dart").write_text(text, encoding='utf-8')
