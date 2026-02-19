import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class WaveformView extends StatefulWidget {
  const WaveformView({
    super.key,
    required this.samples,
    required this.duration,
    required this.showSamplePoints,
  });

  final List<double> samples;
  final Duration duration;
  final bool showSamplePoints;

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView> {
  double _zoom = 1.0;
  double _pan = 0.0;
  double _zoomAtScaleStart = 1.0;

  @override
  void didUpdateWidget(covariant WaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples.length != widget.samples.length) {
      _pan = _pan.clamp(0.0, 1.0);
      _zoom = _zoom.clamp(1.0, 250.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);

        return Stack(
          children: [
            Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  setState(() {
                    final factor = signal.scrollDelta.dy > 0 ? 0.92 : 1.08;
                    _zoom = (_zoom * factor).clamp(1.0, 250.0);
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) {
                  _zoomAtScaleStart = _zoom;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount >= 2) {
                    setState(() {
                      _zoom = (_zoomAtScaleStart * details.scale).clamp(1.0, 250.0);
                      _pan = (_pan - (details.focalPointDelta.dx / width) * (1 / _zoom)).clamp(0.0, 1.0);
                    });
                  }
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _pan = (_pan - (details.delta.dx / width) * (1 / _zoom)).clamp(0.0, 1.0);
                  });
                },
                child: CustomPaint(
                  painter: _WaveformPainter(
                    samples: widget.samples,
                    duration: widget.duration,
                    zoom: _zoom,
                    pan: _pan,
                    showSamplePoints: widget.showSamplePoints,
                    theme: Theme.of(context),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _zoom = 1.0;
                    _pan = 0.0;
                  });
                },
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Reset view'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.duration,
    required this.zoom,
    required this.pan,
    required this.showSamplePoints,
    required this.theme,
  });

  final List<double> samples;
  final Duration duration;
  final double zoom;
  final double pan;
  final bool showSamplePoints;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF111723);
    canvas.drawRect(Offset.zero & size, background);

    _drawGrid(canvas, size);

    if (samples.isEmpty) {
      _drawCenteredLabel(canvas, size, 'Load audio to render waveform');
      return;
    }

    final visibleSamples = (samples.length / zoom).round().clamp(32, samples.length);
    final startIndex = ((samples.length - visibleSamples) * pan).round().clamp(0, samples.length - visibleSamples);
    final endIndex = math.min(samples.length, startIndex + visibleSamples);
    final sectionLength = endIndex - startIndex;

    final centerY = size.height / 2;
    final amplitudeScale = size.height * 0.42;
    final wavePaint = Paint()
      ..color = const Color(0xFF74DAFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final pointsPerPixel = sectionLength / math.max(1.0, size.width);
    if (pointsPerPixel > 2.0) {
      for (var x = 0; x < size.width; x++) {
        final rangeStart = startIndex + (x * pointsPerPixel).floor();
        final rangeEnd = math.min(endIndex, startIndex + ((x + 1) * pointsPerPixel).ceil());
        var minSample = 1.0;
        var maxSample = -1.0;
        for (var sampleIndex = rangeStart; sampleIndex < rangeEnd; sampleIndex++) {
          final sample = samples[sampleIndex];
          if (sample < minSample) {
            minSample = sample;
          }
          if (sample > maxSample) {
            maxSample = sample;
          }
        }

        final yTop = centerY - (maxSample * amplitudeScale);
        final yBottom = centerY - (minSample * amplitudeScale);
        canvas.drawLine(Offset(x.toDouble(), yTop), Offset(x.toDouble(), yBottom), wavePaint);
      }
    } else {
      final waveformPath = Path();
      for (var index = startIndex; index < endIndex; index++) {
        final x = ((index - startIndex) / math.max(1, sectionLength - 1)) * size.width;
        final y = centerY - (samples[index] * amplitudeScale);

        if (index == startIndex) {
          waveformPath.moveTo(x, y);
        } else {
          waveformPath.lineTo(x, y);
        }

        if (showSamplePoints) {
          canvas.drawCircle(
            Offset(x, y),
            1.2,
            Paint()..color = const Color(0xFF9DE8FF),
          );
        }
      }
      canvas.drawPath(waveformPath, wavePaint);
    }

    final axisPaint = Paint()
      ..color = const Color(0xFF2A3546)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);

    final startTime = _fractionToDuration(startIndex / math.max(1, samples.length - 1));
    final endTime = _fractionToDuration((endIndex - 1) / math.max(1, samples.length - 1));
    _drawTimeLabels(canvas, size, startTime, endTime);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2634)
      ..strokeWidth = 1;

    const verticalDivisions = 12;
    const horizontalDivisions = 6;

    for (var column = 1; column < verticalDivisions; column++) {
      final x = size.width * (column / verticalDivisions);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var row = 1; row < horizontalDivisions; row++) {
      final y = size.height * (row / horizontalDivisions);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  Duration _fractionToDuration(double fraction) {
    final clampedFraction = fraction.clamp(0.0, 1.0);
    return Duration(
      microseconds: (duration.inMicroseconds * clampedFraction).round(),
    );
  }

  void _drawTimeLabels(Canvas canvas, Size size, Duration start, Duration end) {
    final textStyle = theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF9FB1C8)) ??
        const TextStyle(color: Color(0xFF9FB1C8), fontSize: 11);

    final left = TextPainter(
      text: TextSpan(text: _formatDuration(start), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    left.paint(canvas, const Offset(12, 8));

    final right = TextPainter(
      text: TextSpan(text: _formatDuration(end), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    right.paint(canvas, Offset(size.width - right.width - 12, 8));
  }

  void _drawCenteredLabel(Canvas canvas, Size size, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF8EA4BF)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 48);

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  String _formatDuration(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds;
    final minutes = (totalMilliseconds ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMilliseconds % 60000) ~/ 1000).toString().padLeft(2, '0');
    final millis = (totalMilliseconds % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.showSamplePoints != showSamplePoints ||
        oldDelegate.duration != duration ||
        oldDelegate.theme != theme;
  }
}
