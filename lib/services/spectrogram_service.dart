import 'dart:math' as math;

import 'package:fft/fft.dart';

class SpectrogramService {
  List<List<double>> buildSpectrogram(
    List<double> samples, {
    int fftSize = 1024,
    int? hopSize,
  }) {
    if (samples.length < fftSize) {
      return const [];
    }

    final safeFftSize = _nearestPowerOfTwo(math.max(256, fftSize));
    final dynamicHop = hopSize ?? math.max(safeFftSize ~/ 4, (samples.length - safeFftSize) ~/ 300);
    final safeHopSize = math.max(1, dynamicHop);
    final output = <List<double>>[];

    for (var offset = 0; offset + safeFftSize <= samples.length; offset += safeHopSize) {
      final chunk = samples.sublist(offset, offset + safeFftSize);
      final windowed = _applyHannWindow(chunk);
      final transformed = _runFft(windowed);
      if (transformed.isEmpty) {
        continue;
      }

      final binCount = safeFftSize ~/ 2;
      final magnitudes = List<double>.filled(binCount, 0.0, growable: false);
      for (var bin = 0; bin < binCount; bin++) {
        final magnitude = _complexMagnitude(transformed[bin]);
        magnitudes[bin] = 20 * math.log(magnitude + 1e-9) / math.ln10;
      }

      output.add(magnitudes);
      if (output.length >= 400) {
        break;
      }
    }

    return _normalize(output);
  }

  List<double> _applyHannWindow(List<double> data) {
    // Manual Hann window implementation (avoids dependency on fft's Window API)
    try {
      final n = data.length;
      final result = List<double>.filled(n, 0.0);
      for (var i = 0; i < n; i++) {
        final multiplier = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (n - 1)));
        result[i] = data[i] * multiplier;
      }
      return result;
    } catch (_) {
      // Fallback below.
    }

    final length = data.length;
    if (length == 1) {
      return List<double>.from(data, growable: false);
    }

    final output = List<double>.filled(length, 0.0, growable: false);
    for (var index = 0; index < length; index++) {
      final weight = 0.5 * (1 - math.cos((2 * math.pi * index) / (length - 1)));
      output[index] = data[index] * weight;
    }
    return output;
  }

  List<dynamic> _runFft(List<double> windowed) {
    try {
      final transformed = FFT.Transform(windowed);
      if (transformed is List) {
        return transformed;
      }
      if (transformed is Iterable) {
        return transformed.toList(growable: false);
      }
    } catch (_) {
      // Fallback below.
    }

    return _naiveDft(windowed);
  }

  List<_ComplexValue> _naiveDft(List<double> samples) {
    final size = samples.length;
    final output = List<_ComplexValue>.filled(size, const _ComplexValue(0.0, 0.0), growable: false);

    for (var frequency = 0; frequency < size; frequency++) {
      var real = 0.0;
      var imaginary = 0.0;
      for (var index = 0; index < size; index++) {
        final angle = -2 * math.pi * frequency * index / size;
        real += samples[index] * math.cos(angle);
        imaginary += samples[index] * math.sin(angle);
      }
      output[frequency] = _ComplexValue(real, imaginary);
    }

    return output;
  }

  double _complexMagnitude(dynamic value) {
    if (value is num) {
      return value.abs().toDouble();
    }
    if (value is _ComplexValue) {
      return value.magnitude;
    }

    try {
      final real = (value.real as num).toDouble();
      final imaginary = (value.imaginary as num).toDouble();
      return math.sqrt((real * real) + (imaginary * imaginary));
    } catch (_) {
      // Continue.
    }

    try {
      final real = (value.x as num).toDouble();
      final imaginary = (value.y as num).toDouble();
      return math.sqrt((real * real) + (imaginary * imaginary));
    } catch (_) {
      // Continue.
    }

    if (value is List && value.length >= 2) {
      final real = (value[0] as num).toDouble();
      final imaginary = (value[1] as num).toDouble();
      return math.sqrt((real * real) + (imaginary * imaginary));
    }

    return 0.0;
  }

  List<List<double>> _normalize(List<List<double>> values) {
    if (values.isEmpty) {
      return const [];
    }

    var minValue = double.infinity;
    var maxValue = double.negativeInfinity;
    for (final row in values) {
      for (final value in row) {
        if (value < minValue) {
          minValue = value;
        }
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }

    final scale = (maxValue - minValue).abs() < 1e-12 ? 1.0 : maxValue - minValue;
    return values
        .map(
          (row) => row
              .map((value) => ((value - minValue) / scale).clamp(0.0, 1.0))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  int _nearestPowerOfTwo(int value) {
    var power = 1;
    while (power < value) {
      power <<= 1;
    }
    return power;
  }
}

class _ComplexValue {
  const _ComplexValue(this.real, this.imaginary);

  final double real;
  final double imaginary;

  double get magnitude => math.sqrt((real * real) + (imaginary * imaginary));
}
