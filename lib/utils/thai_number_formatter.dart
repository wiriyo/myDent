class ThaiNumberFormatter {
  const ThaiNumberFormatter._();

  static String formatPhoneNumber(String? input) {
    final digits = _extractDigits(input);
    if (digits.isEmpty) {
      return '';
    }
    return _applyBlocks(digits, const [3, 3, 5]);
  }

  static String _extractDigits(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }
    return input.replaceAll(RegExp(r'\D'), '');
  }

  static String _applyBlocks(String digits, List<int> blocks) {
    final buffer = StringBuffer();
    var index = 0;

    for (final block in blocks) {
      if (index >= digits.length) {
        break;
      }

      final end = (index + block) > digits.length ? digits.length : index + block;
      if (buffer.isNotEmpty) {
        buffer.write('-');
      }
      buffer.write(digits.substring(index, end));
      index = end;
    }

    return buffer.toString();
  }
}
