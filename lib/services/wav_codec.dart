import 'dart:math' as math;
import 'dart:typed_data';

class DecodedWavData {
  const DecodedWavData({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
  });

  final List<double> samples;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
}

class WavCodec {
  static bool isWav(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    return _ascii(bytes, 0, 4) == 'RIFF' && _ascii(bytes, 8, 4) == 'WAVE';
  }

  static DecodedWavData decode(Uint8List bytes) {
    if (!isWav(bytes)) {
      throw const FormatException('Not a WAV file.');
    }

    final byteData = ByteData.sublistView(bytes);
    int offset = 12;
    int? fmtOffset;
    int? fmtSize;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, 4);
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);
      final chunkDataOffset = offset + 8;

      if (chunkDataOffset + chunkSize > bytes.length) {
        break;
      }

      if (chunkId == 'fmt ') {
        fmtOffset = chunkDataOffset;
        fmtSize = chunkSize;
      } else if (chunkId == 'data') {
        dataOffset = chunkDataOffset;
        dataSize = chunkSize;
      }

      offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (fmtOffset == null || fmtSize == null || dataOffset == null || dataSize == null) {
      throw const FormatException('Missing WAV chunks.');
    }

    final audioFormat = byteData.getUint16(fmtOffset, Endian.little);
    final channels = byteData.getUint16(fmtOffset + 2, Endian.little);
    final sampleRate = byteData.getUint32(fmtOffset + 4, Endian.little);
    final blockAlign = byteData.getUint16(fmtOffset + 12, Endian.little);
    final bitsPerSample = byteData.getUint16(fmtOffset + 14, Endian.little);

    if (channels <= 0 || sampleRate <= 0 || blockAlign <= 0) {
      throw const FormatException('Invalid WAV format values.');
    }

    if (audioFormat != 1 && audioFormat != 3) {
      throw FormatException('Unsupported WAV encoding: $audioFormat');
    }

    final bytesPerChannelSample = bitsPerSample ~/ 8;
    if (bytesPerChannelSample <= 0) {
      throw const FormatException('Invalid bits per sample.');
    }

    final frameCount = dataSize ~/ blockAlign;
    final samples = List<double>.filled(frameCount, 0.0, growable: false);

    for (var frame = 0; frame < frameCount; frame++) {
      var mixed = 0.0;
      for (var channel = 0; channel < channels; channel++) {
        final sampleOffset = dataOffset + frame * blockAlign + channel * bytesPerChannelSample;
        mixed += _decodeSample(
          bytes: bytes,
          data: byteData,
          offset: sampleOffset,
          bitsPerSample: bitsPerSample,
          audioFormat: audioFormat,
        );
      }
      samples[frame] = (mixed / channels).clamp(-1.0, 1.0);
    }

    return DecodedWavData(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
    );
  }

  static Uint8List encode16BitMono({required List<double> samples, required int sampleRate}) {
    final safeSampleRate = sampleRate <= 0 ? 44100 : sampleRate;
    final dataSize = samples.length * 2;
    final totalSize = 44 + dataSize;
    final bytes = Uint8List(totalSize);
    final data = ByteData.sublistView(bytes);

    _writeAscii(bytes, 0, 'RIFF');
    data.setUint32(4, totalSize - 8, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');
    _writeAscii(bytes, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, safeSampleRate, Endian.little);
    data.setUint32(28, safeSampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    _writeAscii(bytes, 36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    var writeOffset = 44;
    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      final value = clamped <= -1.0
          ? -32768
          : math.min(32767, (clamped * 32767.0).round());
      data.setInt16(writeOffset, value, Endian.little);
      writeOffset += 2;
    }

    return bytes;
  }

  static double _decodeSample({
    required Uint8List bytes,
    required ByteData data,
    required int offset,
    required int bitsPerSample,
    required int audioFormat,
  }) {
    if (audioFormat == 3) {
      if (bitsPerSample == 32) {
        return data.getFloat32(offset, Endian.little);
      }
      if (bitsPerSample == 64) {
        return data.getFloat64(offset, Endian.little);
      }
      throw FormatException('Unsupported WAV float bit depth: $bitsPerSample');
    }

    switch (bitsPerSample) {
      case 8:
        return (data.getUint8(offset) - 128) / 128.0;
      case 16:
        return data.getInt16(offset, Endian.little) / 32768.0;
      case 24:
        final b0 = data.getUint8(offset);
        final b1 = data.getUint8(offset + 1);
        final b2 = data.getUint8(offset + 2);
        var value = b0 | (b1 << 8) | (b2 << 16);
        if ((value & 0x800000) != 0) {
          value -= 0x1000000;
        }
        return value / 8388608.0;
      case 32:
        return data.getInt32(offset, Endian.little) / 2147483648.0;
      default:
        throw FormatException('Unsupported WAV PCM bit depth: $bitsPerSample');
    }
  }

  static String _ascii(Uint8List bytes, int offset, int count) {
    final codes = bytes.sublist(offset, offset + count);
    return String.fromCharCodes(codes);
  }

  static void _writeAscii(Uint8List bytes, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }
}
