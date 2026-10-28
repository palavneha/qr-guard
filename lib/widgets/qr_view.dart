import 'package:flutter/material.dart';
import '../services/qr_generator_service.dart';

class QrView extends StatelessWidget {
  const QrView({
    super.key,
    required this.data,
    this.size = 220,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF0A1628),
  });

  final String data;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final matrix = QrGeneratorService.generate(data);

    if (matrix == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Enter content to generate QR',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size - 24, size - 24),
        painter: _QrPainter(
          matrix: matrix,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.matrix, required this.color});

  final QrCodeMatrix matrix;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moduleSize = size.width / matrix.size;

    for (int r = 0; r < matrix.size; r++) {
      for (int c = 0; c < matrix.size; c++) {
        if (matrix.modules[r][c]) {
          final rect = Rect.fromLTWH(
            c * moduleSize,
            r * moduleSize,
            moduleSize + 0.3, // Slight overlap to prevent subpixel antialiasing gaps
            moduleSize + 0.3,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.matrix != matrix || oldDelegate.color != color;
  }
}
