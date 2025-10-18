import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

Future<Uint8List> encodeTis620(String text) async {
  final bytes = await CharsetConverter.encode('TIS-620', text);
  return Uint8List.fromList(bytes);
}

const bool charsetConverterAvailable = true;
