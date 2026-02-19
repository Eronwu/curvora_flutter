import 'package:flutter/material.dart';

class SpectrogramView extends StatelessWidget {
  const SpectrogramView({
    super.key,
    required this.spectrogram,
  });

  final List<List<double>> spectrogram;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpectrogramPainter(
        spectrogram: spectrogram,
        theme: Theme.of(context),
      ),
      size: Size.infinite,
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  const _SpectrogramPainter({
    required this.spectrogram,
    required this.theme,
  });

  final List<List<double>> spectrogram;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101722),
    );

    if (spectrogram.isEmpty || spectrogram.first.isEmpty) {
      _drawCenteredLabel(canvas, size, 'No spectrogram available');
      return;
    }

    final columns = spectrogram.length;
    final rows = spectrogram.first.length;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final paint = Paint();

    for (var x = 0; x < columns; x++) {
      final rowData = spectrogram[x];
      for (var y = 0; y < rows; y++) {
        final intensity = rowData[y].clamp(0.0, 1.0);
        paint.color = _gradientColor(intensity);
        final drawY = size.height - ((y + 1) * cellHeight);
        canvas.drawRect(
          Rect.fromLTWH(x * cellWidth, drawY, cellWidth + 0.5, cellHeight + 0.5),
          paint,
        );
      }
    }
  }

  Color _gradientColor(double intensity) {
    if (intensity < 0.2) {
      return Color.lerp(const Color(0xFF0B1020), const Color(0xFF16355D), intensity / 0.2)!;
    }
    if (intensity < 0.5) {
      return Color.lerp(const Color(0xFF16355D), const Color(0xFF2D90D7), (intensity - 0.2) / 0.3)!;
    }
    if (intensity < 0.8) {
      return Color.lerp(const Color(0xFF2D90D7), const Color(0xFF7EE6FF), (intensity - 0.5) / 0.3)!;
    }
    return Color.lerp(const Color(0xFF7EE6FF), const Color(0xFFFFE29A), (intensity - 0.8) / 0.2)!;
  }

  void _drawCenteredLabel(Canvas canvas, Size size, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF89A0BC)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 48);

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) {
    return oldDelegate.spectrogram != spectrogram || oldDelegate.theme != theme;
  }
}
