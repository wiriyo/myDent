from pathlib import Path
text = Path('lib/screens/patient_add.dart').read_text(encoding='utf-8')
start = text.index('Widget _getGenderIcon')
print(text[start:start+200])
