import 'package:flutter_test/flutter_test.dart';
import 'package:madl_project/services/qr_generator_service.dart';

void main() {
  group('QrGeneratorService', () {
    test('returns null for empty string', () {
      expect(QrGeneratorService.generate(''), isNull);
    });

    test('generates valid matrix for small string', () {
      final matrix = QrGeneratorService.generate('Hello');
      expect(matrix, isNotNull);
      expect(matrix!.size, 21); // Version 1 is 21x21
      expect(matrix.modules.length, 21);
      expect(matrix.modules[0].length, 21);

      // Verify finder pattern at top-left (0,0) is black
      expect(matrix.modules[0][0], isTrue);
      // Center of finder pattern (3,3) is black
      expect(matrix.modules[3][3], isTrue);
    });

    test('scales version for longer URL string', () {
      final matrix = QrGeneratorService.generate('https://example.com/very/long/path/for/qr');
      expect(matrix, isNotNull);
      expect(matrix!.size, greaterThan(21));
    });
  });
}
