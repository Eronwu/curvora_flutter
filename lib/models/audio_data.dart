import 'dart:typed_data';

enum AudioDecodeQuality { exact, estimated }

class AudioData {
  const AudioData({
    required this.filePath,
    required this.fileName,
    required this.extension,
    required this.sourceBytes,
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.duration,
    required this.sampleCount,
    required this.decodeQuality,
  });

  final String filePath;
  final String fileName;
  final String extension;
  final Uint8List sourceBytes;
  final List<double> samples;
  final int sampleRate;
  final int channels;
  final Duration duration;
  final int sampleCount;
  final AudioDecodeQuality decodeQuality;

  bool get isExactDecode => decodeQuality == AudioDecodeQuality.exact;
}
