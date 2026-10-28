import 'dart:math';

/// A pure Dart QR Code matrix generator for Model 2 QR codes.
/// Supports byte encoding (UTF-8/ASCII) up to Version 4 (up to 114 alphanumeric/URL characters).
class QrCodeMatrix {
  QrCodeMatrix(this.size)
      : modules = List.generate(size, (_) => List.filled(size, false)),
        isFunction = List.generate(size, (_) => List.filled(size, false));

  final int size;
  final List<List<bool>> modules;
  final List<List<bool>> isFunction;

  void set(int r, int c, bool val, {bool function = false}) {
    modules[r][c] = val;
    if (function) isFunction[r][c] = true;
  }
}

class QrGeneratorService {
  const QrGeneratorService();

  static QrCodeMatrix? generate(String text) {
    if (text.isEmpty) return null;
    final bytes = text.codeUnits;

    // Pick version (1: 17 bytes, 2: 32 bytes, 3: 53 bytes, 4: 78 bytes with EC Level M)
    int version = 1;
    if (bytes.length <= 14) {
      version = 1;
    } else if (bytes.length <= 26) {
      version = 2;
    } else if (bytes.length <= 42) {
      version = 3;
    } else if (bytes.length <= 62) {
      version = 4;
    } else if (bytes.length <= 106) {
      version = 6;
    } else {
      // Fallback: truncate to 106 bytes if oversized
      version = 6;
    }

    final size = version * 4 + 17;
    final qr = QrCodeMatrix(size);

    _addFinderPatterns(qr);
    _addAlignmentPatterns(qr, version);
    _addTimingPatterns(qr);
    _addDarkModule(qr, version);
    _reserveFormatArea(qr);

    // Encode data
    final dataBits = _encodeData(bytes, version);
    final totalCodewords = _totalDataCodewords(version);
    final ecCodewords = _ecCodewords(version);

    final dataCodewords = _bitsToCodewords(dataBits, totalCodewords);
    final ec = _reedSolomon(dataCodewords, ecCodewords);

    final allCodewords = [...dataCodewords, ...ec];
    _placeData(qr, allCodewords);

    // Apply best mask (mask 0: (r + c) % 2 == 0)
    _applyMaskAndFormat(qr, 0);

    return qr;
  }

  static void _addFinderPatterns(QrCodeMatrix qr) {
    void placeFinder(int r0, int c0) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final isEdge = r == 0 || r == 6 || c == 0 || c == 6;
          final isCenter = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          qr.set(r0 + r, c0 + c, isEdge || isCenter, function: true);
        }
      }
      // Separator
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          if (r == -1 || r == 7 || c == -1 || c == 7) {
            final rr = r0 + r;
            final cc = c0 + c;
            if (rr >= 0 && rr < qr.size && cc >= 0 && cc < qr.size) {
              qr.set(rr, cc, false, function: true);
            }
          }
        }
      }
    }

    placeFinder(0, 0);
    placeFinder(0, qr.size - 7);
    placeFinder(qr.size - 7, 0);
  }

  static void _addAlignmentPatterns(QrCodeMatrix qr, int version) {
    if (version < 2) return;
    final pos = switch (version) {
      2 => [6, 18],
      3 => [6, 22],
      4 => [6, 26],
      _ => [6, 34],
    };

    for (final r in pos) {
      for (final c in pos) {
        if (qr.isFunction[r][c]) continue;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final isEdge = dr.abs() == 2 || dc.abs() == 2;
            final isCenter = dr == 0 && dc == 0;
            qr.set(r + dr, c + dc, isEdge || isCenter, function: true);
          }
        }
      }
    }
  }

  static void _addTimingPatterns(QrCodeMatrix qr) {
    for (int i = 8; i < qr.size - 8; i++) {
      final val = i % 2 == 0;
      if (!qr.isFunction[6][i]) qr.set(6, i, val, function: true);
      if (!qr.isFunction[i][6]) qr.set(i, 6, val, function: true);
    }
  }

  static void _addDarkModule(QrCodeMatrix qr, int version) {
    qr.set(4 * version + 9, 8, true, function: true);
  }

  static void _reserveFormatArea(QrCodeMatrix qr) {
    for (int i = 0; i < 9; i++) {
      if (i != 6) {
        qr.set(8, i, false, function: true);
        qr.set(i, 8, false, function: true);
      }
    }
    for (int i = 0; i < 8; i++) {
      qr.set(8, qr.size - 1 - i, false, function: true);
      qr.set(qr.size - 1 - i, 8, false, function: true);
    }
  }

  static List<int> _encodeData(List<int> bytes, int version) {
    final bits = <int>[];
    // Mode indicator for Byte Mode: 0100
    bits.addAll([0, 1, 0, 0]);

    // Character count indicator (8 bits for V1-9 in Byte mode)
    final len = min(bytes.length, 106);
    for (int i = 7; i >= 0; i--) {
      bits.add((len >> i) & 1);
    }

    // Bytes
    for (int i = 0; i < len; i++) {
      final b = bytes[i];
      for (int j = 7; j >= 0; j--) {
        bits.add((b >> j) & 1);
      }
    }

    // Terminator (up to 4 zeroes)
    final totalDataBits = _totalDataCodewords(version) * 8;
    final termLen = min(4, totalDataBits - bits.length);
    for (int i = 0; i < termLen; i++) {
      bits.add(0);
    }

    // Byte align
    while (bits.length % 8 != 0) {
      bits.add(0);
    }

    return bits;
  }

  static List<int> _bitsToCodewords(List<int> bits, int targetCount) {
    final codewords = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int val = 0;
      for (int j = 0; j < 8; j++) {
        val = (val << 1) | bits[i + j];
      }
      codewords.add(val);
    }

    // Pad bytes 0xEC, 0x11
    final pad = [0xEC, 0x11];
    var padIdx = 0;
    while (codewords.length < targetCount) {
      codewords.add(pad[padIdx % 2]);
      padIdx++;
    }

    return codewords;
  }

  static int _totalDataCodewords(int version) => switch (version) {
        1 => 16,
        2 => 28,
        3 => 44,
        4 => 64,
        _ => 108,
      };

  static int _ecCodewords(int version) => switch (version) {
        1 => 10,
        2 => 16,
        3 => 26,
        4 => 36,
        _ => 44,
      };

  static List<int> _reedSolomon(List<int> data, int ecCount) {
    final exp = List.filled(512, 0);
    final log = List.filled(256, 0);
    var x = 1;
    for (int i = 0; i < 255; i++) {
      exp[i] = x;
      exp[i + 255] = x;
      log[x] = i;
      x = (x << 1) ^ (x >= 128 ? 0x11D : 0);
    }

    int gMul(int a, int b) {
      if (a == 0 || b == 0) return 0;
      return exp[log[a] + log[b]];
    }

    // Generator polynomial
    var gen = [1];
    for (int i = 0; i < ecCount; i++) {
      final nextGen = List.filled(gen.length + 1, 0);
      for (int j = 0; j < gen.length; j++) {
        nextGen[j] ^= gMul(gen[j], exp[i]);
        nextGen[j + 1] ^= gen[j];
      }
      gen = nextGen;
    }

    final res = List.filled(ecCount, 0);
    for (final d in data) {
      final factor = d ^ res[0];
      for (int i = 0; i < ecCount - 1; i++) {
        res[i] = res[i + 1] ^ gMul(gen[gen.length - 2 - i], factor);
      }
      res[ecCount - 1] = gMul(gen[0], factor);
    }

    return res;
  }

  static void _placeData(QrCodeMatrix qr, List<int> codewords) {
    final bits = <int>[];
    for (final c in codewords) {
      for (int i = 7; i >= 0; i--) {
        bits.add((c >> i) & 1);
      }
    }

    var bitIdx = 0;
    var upward = true;
    for (int right = qr.size - 1; right > 0; right -= 2) {
      if (right == 6) right--; // Skip vertical timing column

      final rows = upward
          ? List.generate(qr.size, (i) => qr.size - 1 - i)
          : List.generate(qr.size, (i) => i);

      for (final r in rows) {
        for (int c = right; c >= right - 1; c--) {
          if (!qr.isFunction[r][c]) {
            final bit = bitIdx < bits.length ? bits[bitIdx++] : 0;
            qr.set(r, c, bit == 1);
          }
        }
      }
      upward = !upward;
    }
  }

  static void _applyMaskAndFormat(QrCodeMatrix qr, int mask) {
    // Mask 0: (r + c) % 2 == 0
    for (int r = 0; r < qr.size; r++) {
      for (int c = 0; c < qr.size; c++) {
        if (!qr.isFunction[r][c]) {
          if ((r + c) % 2 == 0) {
            qr.modules[r][c] = !qr.modules[r][c];
          }
        }
      }
    }

    // Format bits for EC Level M (00) + Mask 0 (000) = 00000 -> 0x5412 XOR
    // Constant BCH-encoded 15-bit format info for (Level M, Mask 0): 101010000010010
    const formatBits = [1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0];

    // Place around top-left
    for (int i = 0; i < 6; i++) {
      qr.modules[8][i] = formatBits[i] == 1;
    }
    qr.modules[8][7] = formatBits[6] == 1;
    qr.modules[8][8] = formatBits[7] == 1;
    qr.modules[7][8] = formatBits[8] == 1;
    for (int i = 9; i < 15; i++) {
      qr.modules[14 - i][8] = formatBits[i] == 1;
    }

    // Place around top-right and bottom-left
    for (int i = 0; i < 8; i++) {
      qr.modules[8][qr.size - 1 - i] = formatBits[i] == 1;
    }
    for (int i = 8; i < 15; i++) {
      qr.modules[qr.size - 15 + i][8] = formatBits[i] == 1;
    }
  }
}
