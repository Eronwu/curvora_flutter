import 'dart:typed_data';

class ProcessedAudio {
  const ProcessedAudio({
    required this.samples,
    required this.sampleRate,
    required this.duration,
    required this.wavBytes,
  });

  final List<double> samples;
  final int sampleRate;
  final Duration duration;
  final Uint8List wavBytes;
}
