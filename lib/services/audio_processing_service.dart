import 'dart:math' as math;

import 'package:curvora_flutter/models/audio_data.dart';
import 'package:curvora_flutter/models/processed_audio.dart';
import 'package:curvora_flutter/models/processing_settings.dart';
import 'package:curvora_flutter/services/wav_codec.dart';

class AudioProcessingService {
  ProcessedAudio process(AudioData audioData, ProcessingSettings settings) {
    final gained = _applyGainAndClipping(
      audioData.samples,
      gain: settings.gain,
      threshold: settings.clippingThreshold,
    );

    final resampled = _resample(
      gained,
      sourceRate: audioData.sampleRate,
      targetRate: settings.targetSampleRate,
      algorithm: settings.resamplingAlgorithm,
    );

    final wavBytes = WavCodec.encode16BitMono(
      samples: resampled,
      sampleRate: settings.targetSampleRate,
    );

    final duration = Duration(
      microseconds:
          resampled.length * Duration.microsecondsPerSecond ~/ math.max(1, settings.targetSampleRate),
    );

    return ProcessedAudio(
      samples: resampled,
      sampleRate: settings.targetSampleRate,
      duration: duration,
      wavBytes: wavBytes,
    );
  }

  List<double> _applyGainAndClipping(
    List<double> samples, {
    required double gain,
    required double threshold,
  }) {
    final safeThreshold = threshold.clamp(0.05, 1.0);
    final output = List<double>.filled(samples.length, 0.0, growable: false);

    for (var index = 0; index < samples.length; index++) {
      var value = samples[index] * gain;
      if (value > safeThreshold) {
        value = safeThreshold;
      } else if (value < -safeThreshold) {
        value = -safeThreshold;
      }

      output[index] = value.clamp(-1.0, 1.0);
    }

    return output;
  }

  List<double> _resample(
    List<double> samples, {
    required int sourceRate,
    required int targetRate,
    required ResamplingAlgorithm algorithm,
  }) {
    if (samples.isEmpty || sourceRate <= 0 || targetRate <= 0 || sourceRate == targetRate) {
      return List<double>.from(samples, growable: false);
    }

    return switch (algorithm) {
      ResamplingAlgorithm.linear => _linearResample(samples, sourceRate: sourceRate, targetRate: targetRate),
      ResamplingAlgorithm.sinc => _sincResample(samples, sourceRate: sourceRate, targetRate: targetRate),
    };
  }

  List<double> _linearResample(
    List<double> samples, {
    required int sourceRate,
    required int targetRate,
  }) {
    final ratio = targetRate / sourceRate;
    final outputLength = math.max(1, (samples.length * ratio).round());
    final output = List<double>.filled(outputLength, 0.0, growable: false);

    for (var index = 0; index < outputLength; index++) {
      final sourceIndex = index / ratio;
      final left = sourceIndex.floor();
      final right = math.min(left + 1, samples.length - 1);
      final blend = sourceIndex - left;
      output[index] = (samples[left] * (1 - blend)) + (samples[right] * blend);
    }

    return output;
  }

  List<double> _sincResample(
    List<double> samples, {
    required int sourceRate,
    required int targetRate,
  }) {
    final ratio = targetRate / sourceRate;
    final outputLength = math.max(1, (samples.length * ratio).round());
    final output = List<double>.filled(outputLength, 0.0, growable: false);
    const halfWindow = 10;

    for (var index = 0; index < outputLength; index++) {
      final sourcePosition = index / ratio;
      final center = sourcePosition.floor();
      var value = 0.0;
      var totalWeight = 0.0;

      for (var tap = -halfWindow; tap <= halfWindow; tap++) {
        final sourceIndex = center + tap;
        if (sourceIndex < 0 || sourceIndex >= samples.length) {
          continue;
        }

        final x = sourcePosition - sourceIndex;
        final lanczosWindow = _sinc(x / halfWindow);
        final sinc = _sinc(x);
        final weight = sinc * lanczosWindow;
        value += samples[sourceIndex] * weight;
        totalWeight += weight;
      }

      output[index] = totalWeight.abs() > 1e-12 ? value / totalWeight : 0.0;
    }

    return output;
  }

  double _sinc(double x) {
    if (x.abs() < 1e-12) {
      return 1.0;
    }
    final scaled = math.pi * x;
    return math.sin(scaled) / scaled;
  }
}
