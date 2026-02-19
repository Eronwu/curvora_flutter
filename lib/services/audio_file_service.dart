import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:curvora_flutter/models/audio_data.dart';
import 'package:curvora_flutter/services/wav_codec.dart';
import 'package:file_picker/file_picker.dart';

class AudioFileService {
  Future<String?> pickAudioPath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'ogg', 'flac'],
      withData: false,
    );

    return result?.files.single.path;
  }

  Future<AudioData> loadFromPath(String filePath) async {
    final file = File(filePath);
    final fileName = _fileNameFromPath(filePath);
    final extension = _extensionFromFileName(fileName);
    final bytes = await file.readAsBytes();

    if (WavCodec.isWav(bytes)) {
      final decoded = WavCodec.decode(bytes);
      final sampleCount = decoded.samples.length;
      final duration = Duration(
        microseconds: (sampleCount * Duration.microsecondsPerSecond ~/ decoded.sampleRate)
            .clamp(0, 1 << 31),
      );

      return AudioData(
        filePath: filePath,
        fileName: fileName,
        extension: extension,
        sourceBytes: bytes,
        samples: decoded.samples,
        sampleRate: decoded.sampleRate,
        channels: decoded.channels,
        duration: duration,
        sampleCount: sampleCount,
        decodeQuality: AudioDecodeQuality.exact,
      );
    }

    final metadata = _estimateMetadata(bytes, extension);
    final sampleRate = metadata.sampleRate ?? 44100;
    final channels = metadata.channels ?? 2;
    final sampleCount = metadata.sampleCount ??
        ((metadata.duration?.inMicroseconds ?? 0) * sampleRate ~/ Duration.microsecondsPerSecond);
    final fallbackSampleCount = sampleCount > 0 ? sampleCount : (bytes.length ~/ 2);
    final duration = metadata.duration ??
        Duration(
          microseconds:
              fallbackSampleCount * Duration.microsecondsPerSecond ~/ math.max(1, sampleRate),
        );

    return AudioData(
      filePath: filePath,
      fileName: fileName,
      extension: extension,
      sourceBytes: bytes,
      samples: _buildPseudoSamples(bytes),
      sampleRate: sampleRate,
      channels: channels,
      duration: duration,
      sampleCount: fallbackSampleCount,
      decodeQuality: AudioDecodeQuality.estimated,
    );
  }

  List<double> _buildPseudoSamples(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const [];
    }

    const targetPointCount = 240000;
    final stride = math.max(1, bytes.length ~/ targetPointCount);
    final sampleCount = (bytes.length / stride).ceil();
    final samples = List<double>.filled(sampleCount, 0.0, growable: false);

    var sampleIndex = 0;
    for (var byteIndex = 0; byteIndex < bytes.length; byteIndex += stride) {
      samples[sampleIndex] = (bytes[byteIndex] - 128) / 128.0;
      sampleIndex += 1;
      if (sampleIndex >= samples.length) {
        break;
      }
    }

    return samples;
  }

  _EstimatedMetadata _estimateMetadata(Uint8List bytes, String extension) {
    return switch (extension) {
      'mp3' => _parseMp3(bytes),
      'ogg' => _parseOgg(bytes),
      'flac' => _parseFlac(bytes),
      _ => _EstimatedMetadata(),
    };
  }

  _EstimatedMetadata _parseMp3(Uint8List bytes) {
    if (bytes.length < 4) {
      return _EstimatedMetadata();
    }

    for (var index = 0; index <= bytes.length - 4; index++) {
      final b0 = bytes[index];
      final b1 = bytes[index + 1];
      if (b0 != 0xFF || (b1 & 0xE0) != 0xE0) {
        continue;
      }

      final b2 = bytes[index + 2];
      final b3 = bytes[index + 3];
      final versionBits = (b1 >> 3) & 0x03;
      final layerBits = (b1 >> 1) & 0x03;
      final bitrateIndex = (b2 >> 4) & 0x0F;
      final sampleRateIndex = (b2 >> 2) & 0x03;
      final channelMode = (b3 >> 6) & 0x03;

      if (layerBits != 0x01 || sampleRateIndex == 0x03 || bitrateIndex == 0 || bitrateIndex == 0x0F) {
        continue;
      }

      final sampleRate = switch (versionBits) {
        0x03 => const [44100, 48000, 32000][sampleRateIndex],
        0x02 => const [22050, 24000, 16000][sampleRateIndex],
        0x00 => const [11025, 12000, 8000][sampleRateIndex],
        _ => 0,
      };
      if (sampleRate == 0) {
        continue;
      }

      final kbps = versionBits == 0x03
          ? const [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0][bitrateIndex]
          : const [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0][bitrateIndex];
      if (kbps == 0) {
        continue;
      }

      final bitrate = kbps * 1000;
      final durationSeconds = (bytes.length * 8) / bitrate;
      final duration = Duration(milliseconds: (durationSeconds * 1000).round());
      final sampleCount = (durationSeconds * sampleRate).round();

      return _EstimatedMetadata(
        sampleRate: sampleRate,
        channels: channelMode == 0x03 ? 1 : 2,
        duration: duration,
        sampleCount: sampleCount,
      );
    }

    return _EstimatedMetadata();
  }

  _EstimatedMetadata _parseOgg(Uint8List bytes) {
    if (bytes.length < 64) {
      return _EstimatedMetadata();
    }

    final vorbisOffset = _indexOf(bytes, 'vorbis'.codeUnits);
    if (vorbisOffset >= 0 && vorbisOffset + 16 < bytes.length) {
      final channels = bytes[vorbisOffset + 11];
      final sampleRateData = ByteData.sublistView(bytes, vorbisOffset + 12, vorbisOffset + 16);
      final sampleRate = sampleRateData.getUint32(0, Endian.little);
      final totalSamples = _extractLastOggGranulePosition(bytes);

      if (sampleRate > 0 && totalSamples != null) {
        final durationSeconds = totalSamples / sampleRate;
        final duration = Duration(milliseconds: (durationSeconds * 1000).round());
        return _EstimatedMetadata(
          sampleRate: sampleRate,
          channels: channels,
          duration: duration,
          sampleCount: totalSamples,
        );
      }

      return _EstimatedMetadata(sampleRate: sampleRate, channels: channels);
    }

    return _EstimatedMetadata();
  }

  _EstimatedMetadata _parseFlac(Uint8List bytes) {
    if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'fLaC') {
      return _EstimatedMetadata();
    }

    var offset = 4;
    while (offset + 4 <= bytes.length) {
      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockType = header & 0x7F;
      final blockLength = (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
      final dataOffset = offset + 4;

      if (dataOffset + blockLength > bytes.length) {
        break;
      }

      if (blockType == 0 && blockLength >= 18) {
        final b10 = bytes[dataOffset + 10];
        final b11 = bytes[dataOffset + 11];
        final b12 = bytes[dataOffset + 12];
        final b13 = bytes[dataOffset + 13];
        final b14 = bytes[dataOffset + 14];
        final b15 = bytes[dataOffset + 15];
        final b16 = bytes[dataOffset + 16];
        final b17 = bytes[dataOffset + 17];

        final sampleRate = (b10 << 12) | (b11 << 4) | (b12 >> 4);
        final channels = ((b12 & 0x0E) >> 1) + 1;
        final totalSamples = ((b13 & 0x0F) << 32) |
            (b14 << 24) |
            (b15 << 16) |
            (b16 << 8) |
            b17;

        if (sampleRate > 0 && totalSamples > 0) {
          final durationSeconds = totalSamples / sampleRate;
          final duration = Duration(milliseconds: (durationSeconds * 1000).round());
          return _EstimatedMetadata(
            sampleRate: sampleRate,
            channels: channels,
            duration: duration,
            sampleCount: totalSamples,
          );
        }

        return _EstimatedMetadata(sampleRate: sampleRate, channels: channels);
      }

      offset = dataOffset + blockLength;
      if (isLast) {
        break;
      }
    }

    return _EstimatedMetadata();
  }

  int? _extractLastOggGranulePosition(Uint8List bytes) {
    if (bytes.length < 28) {
      return null;
    }

    const signature = 'OggS';
    for (var index = bytes.length - 28; index >= 0; index--) {
      if (_matchesAscii(bytes, index, signature)) {
        final granuleData = ByteData.sublistView(bytes, index + 6, index + 14);
        final low = granuleData.getUint32(0, Endian.little);
        final high = granuleData.getUint32(4, Endian.little);
        final value = (high * 0x100000000) + low;
        if (value > 0 && value <= 0x7FFFFFFFFFFFFFFF) {
          return value;
        }
      }
    }

    return null;
  }

  int _indexOf(Uint8List bytes, List<int> pattern) {
    if (pattern.isEmpty || bytes.length < pattern.length) {
      return -1;
    }

    for (var index = 0; index <= bytes.length - pattern.length; index++) {
      var matched = true;
      for (var patternIndex = 0; patternIndex < pattern.length; patternIndex++) {
        if (bytes[index + patternIndex] != pattern[patternIndex]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return index;
      }
    }

    return -1;
  }

  bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }

  String _fileNameFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? filePath : parts.last;
  }

  String _extensionFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dot + 1).toLowerCase();
  }
}

class _EstimatedMetadata {
  _EstimatedMetadata({
    this.sampleRate,
    this.channels,
    this.duration,
    this.sampleCount,
  });

  final int? sampleRate;
  final int? channels;
  final Duration? duration;
  final int? sampleCount;
}
