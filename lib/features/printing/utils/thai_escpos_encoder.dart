import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'thai_charset_converter_stub.dart'
    if (dart.library.io) 'thai_charset_converter_io.dart'
    as charset;

class ThaiEscPosPayload {
  const ThaiEscPosPayload({
    required this.bytes,
    required this.command,
    required this.codePages,
    this.encoding = 'TIS-620',
  });

  final Uint8List bytes;
  final String command;
  final List<int> codePages;
  final String encoding;
}

class ThaiEscPosEncoder {
  ThaiEscPosEncoder._();

  static const List<int> _internationalThailand = <int>[0x1b, 0x52, 0x15];
  static const List<int> _codePagePrimary = <int>[0x1b, 0x74, 0x46];
  static const List<int> _codePageFallback = <int>[0x1b, 0x74, 0xff];
  static const List<int> _cutCommand = <int>[0x1d, 0x56, 0x00];

  static const Map<int, int> _pc874Map = <int, int>{
    0x0e01: 0xa1,
    0x0e02: 0xa2,
    0x0e03: 0xa3,
    0x0e04: 0xa4,
    0x0e05: 0xa5,
    0x0e06: 0xa6,
    0x0e07: 0xa7,
    0x0e08: 0xa8,
    0x0e09: 0xa9,
    0x0e0a: 0xaa,
    0x0e0b: 0xab,
    0x0e0c: 0xac,
    0x0e0d: 0xad,
    0x0e0e: 0xae,
    0x0e0f: 0xaf,
    0x0e10: 0xb0,
    0x0e11: 0xb1,
    0x0e12: 0xb2,
    0x0e13: 0xb3,
    0x0e14: 0xb4,
    0x0e15: 0xb5,
    0x0e16: 0xb6,
    0x0e17: 0xb7,
    0x0e18: 0xb8,
    0x0e19: 0xb9,
    0x0e1a: 0xba,
    0x0e1b: 0xbb,
    0x0e1c: 0xbc,
    0x0e1d: 0xbd,
    0x0e1e: 0xbe,
    0x0e1f: 0xbf,
    0x0e20: 0xc0,
    0x0e21: 0xc1,
    0x0e22: 0xc2,
    0x0e23: 0xc3,
    0x0e24: 0xc4,
    0x0e25: 0xc5,
    0x0e26: 0xc6,
    0x0e27: 0xc7,
    0x0e28: 0xc8,
    0x0e29: 0xc9,
    0x0e2a: 0xca,
    0x0e2b: 0xcb,
    0x0e2c: 0xcc,
    0x0e2d: 0xcd,
    0x0e2e: 0xce,
    0x0e2f: 0xcf,
    0x0e30: 0xd0,
    0x0e31: 0xd1,
    0x0e32: 0xd2,
    0x0e33: 0xd3,
    0x0e34: 0xd4,
    0x0e35: 0xd5,
    0x0e36: 0xd6,
    0x0e37: 0xd7,
    0x0e38: 0xd8,
    0x0e39: 0xd9,
    0x0e3a: 0xda,
    0x0e3f: 0xdb,
    0x0e40: 0xdc,
    0x0e41: 0xdd,
    0x0e42: 0xde,
    0x0e43: 0xdf,
    0x0e44: 0xe0,
    0x0e45: 0xe1,
    0x0e46: 0xe2,
    0x0e47: 0xe3,
    0x0e48: 0xe4,
    0x0e49: 0xe5,
    0x0e4a: 0xe6,
    0x0e4b: 0xe7,
    0x0e4c: 0xe8,
    0x0e4d: 0xe9,
    0x0e4e: 0xea,
    0x0e4f: 0xeb,
    0x0e50: 0xec,
    0x0e51: 0xed,
    0x0e52: 0xee,
    0x0e53: 0xef,
    0x0e54: 0xf0,
    0x0e55: 0xf1,
    0x0e56: 0xf2,
    0x0e57: 0xf3,
    0x0e58: 0xf4,
    0x0e59: 0xf5,
    0x0e5a: 0xf6,
    0x0e5b: 0xf7,
  };

  static Future<ThaiEscPosPayload> buildThaiPayload(
    String text, {
    bool includeCut = true,
  }) async {
    final String normalized = text.endsWith('\n') ? text : '$text\n';
    final Uint8List textBytes = await _encodeThai(normalized);
    final BytesBuilder builder = BytesBuilder();
    builder.add(_internationalThailand);
    builder.add(_codePagePrimary);
    builder.add(_codePageFallback);
    builder.add(textBytes);
    if (includeCut) {
      builder.add(<int>[0x0a]); // LF before cut
      builder.add(_cutCommand);
    }
    final Uint8List bytes = builder.toBytes();
    final String command = _bytesToEscString(bytes);
    if (kDebugMode) {
      debugPrint(
        '[MyDent|POS] Prepared ESC/POS payload: codePages=[70,255], encoding=TIS-620, bytes=${bytes.length}',
      );
    }
    return ThaiEscPosPayload(
      bytes: bytes,
      command: command,
      codePages: const <int>[70, 255],
    );
  }

  static Future<Uint8List> _encodeThai(String text) async {
    if (charset.charsetConverterAvailable) {
      try {
        return await charset.encodeTis620(text);
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[MyDent|POS] charset_converter encode failed: $error\n$stackTrace',
          );
        }
      }
    }
    return _fallbackEncode(text);
  }

  static Uint8List _fallbackEncode(String text) {
    final List<int> buffer = <int>[];
    for (final int rune in text.runes) {
      if (rune == 0x0a || rune == 0x0d) {
        buffer.add(rune);
      } else if (rune >= 0x00 && rune <= 0x7f) {
        buffer.add(rune);
      } else {
        buffer.add(_pc874Map[rune] ?? 0x3f);
      }
    }
    return Uint8List.fromList(buffer);
  }

  static String _bytesToEscString(Uint8List bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write(r'\x');
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
