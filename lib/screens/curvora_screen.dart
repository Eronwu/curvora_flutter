import 'dart:async';
import 'dart:io';

import 'package:curvora_flutter/models/audio_data.dart';
import 'package:curvora_flutter/models/processed_audio.dart';
import 'package:curvora_flutter/models/processing_settings.dart';
import 'package:curvora_flutter/services/audio_file_service.dart';
import 'package:curvora_flutter/services/audio_processing_service.dart';
import 'package:curvora_flutter/services/spectrogram_service.dart';
import 'package:curvora_flutter/widgets/control_panel.dart';
import 'package:curvora_flutter/widgets/spectrogram_view.dart';
import 'package:curvora_flutter/widgets/waveform_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class CurvoraScreen extends StatefulWidget {
  const CurvoraScreen({super.key});

  @override
  State<CurvoraScreen> createState() => _CurvoraScreenState();
}

class _CurvoraScreenState extends State<CurvoraScreen> {
  final AudioFileService _audioFileService = AudioFileService();
  final AudioProcessingService _audioProcessingService = AudioProcessingService();
  final SpectrogramService _spectrogramService = SpectrogramService();

  ProcessingSettings _settings = const ProcessingSettings();
  AudioData? _audioData;
  ProcessedAudio? _processedAudio;
  List<List<double>> _spectrogram = const [];

  bool _isBusy = false;
  bool _isPlaying = false;
  bool _isPlayingProcessed = false;
  bool _isPaused = false;
  String? _statusMessage = 'Load a WAV/MP3/OGG/FLAC file to begin.';

  Timer? _playbackTimer;
  Duration _remainingPlayback = Duration.zero;
  DateTime? _playbackStartedAt;

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage = 'Opening file picker...';
    });

    try {
      final path = await _audioFileService.pickAudioPath();
      if (path == null) {
        setState(() {
          _isBusy = false;
          _statusMessage = 'File selection canceled.';
        });
        return;
      }

      final audioData = await _audioFileService.loadFromPath(path);
      final processed = _audioProcessingService.process(audioData, _settings);
      final spectrogram = _spectrogramService.buildSpectrogram(processed.samples);

      _stopPlayback(updateStatus: false);
      if (!mounted) {
        return;
      }

      setState(() {
        _audioData = audioData;
        _processedAudio = processed;
        _spectrogram = spectrogram;
        _isBusy = false;
        _statusMessage = _buildLoadedStatus(audioData, processed);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _statusMessage = 'Failed to load audio: $error';
      });
    }
  }

  void _onSettingsChanged(ProcessingSettings value) {
    setState(() {
      _settings = value;
    });

    final audioData = _audioData;
    if (audioData == null) {
      return;
    }

    try {
      final processed = _audioProcessingService.process(audioData, value);
      final spectrogram = _spectrogramService.buildSpectrogram(processed.samples);
      setState(() {
        _processedAudio = processed;
        _spectrogram = spectrogram;
        _statusMessage = _buildReprocessedStatus(audioData, processed);
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Reprocessing failed: $error';
      });
    }
  }

  void _playOriginal() {
    final audioData = _audioData;
    if (audioData == null) {
      return;
    }
    _startPlayback(
      duration: audioData.duration,
      isProcessed: false,
      label: 'original',
    );
  }

  void _playProcessed() {
    final processed = _processedAudio;
    if (processed == null) {
      return;
    }
    _startPlayback(
      duration: processed.duration,
      isProcessed: true,
      label: 'processed',
    );
  }

  void _pauseOrResume() {
    if (!_isPlaying) {
      if (_isPaused) {
        _resumePlayback();
      } else {
        _statusMessage = 'Select Original or Processed to start preview.';
      }

      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (_isPaused) {
      _resumePlayback();
    } else {
      _pausePlayback();
    }
  }

  void _startPlayback({
    required Duration duration,
    required bool isProcessed,
    required String label,
  }) {
    _playbackTimer?.cancel();
    _remainingPlayback = duration;
    _playbackStartedAt = DateTime.now();

    setState(() {
      _isPlaying = true;
      _isPlayingProcessed = isProcessed;
      _isPaused = false;
      _statusMessage =
          'Previewing $label track (visual timer only in this build).';
    });

    _playbackTimer = Timer(duration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _isPlayingProcessed = isProcessed;
        _remainingPlayback = Duration.zero;
        _playbackStartedAt = null;
        _statusMessage = 'Preview finished.';
      });
    });
  }

  void _pausePlayback() {
    if (!_isPlaying) {
      return;
    }

    final startedAt = _playbackStartedAt;
    final elapsed =
        startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
    final remaining = _remainingPlayback - elapsed;
    _remainingPlayback = remaining > Duration.zero ? remaining : Duration.zero;

    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _statusMessage = 'Preview paused.';
    });
  }

  void _resumePlayback() {
    if (!_isPaused || _remainingPlayback <= Duration.zero) {
      return;
    }

    _playbackStartedAt = DateTime.now();
    _playbackTimer = Timer(_remainingPlayback, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _remainingPlayback = Duration.zero;
        _playbackStartedAt = null;
        _statusMessage = 'Preview finished.';
      });
    });

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _statusMessage = 'Preview resumed.';
    });
  }

  void _stopPlayback({bool updateStatus = true}) {
    _playbackTimer?.cancel();
    _playbackStartedAt = null;
    _remainingPlayback = Duration.zero;

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
      _isPaused = false;
      if (updateStatus) {
        _statusMessage = 'Preview stopped.';
      }
    });
  }

  Future<void> _exportProcessedWav() async {
    final source = _audioData;
    final processed = _processedAudio;
    if (source == null || processed == null || _isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage = 'Preparing export...';
    });

    try {
      final defaultFileName = _buildExportFileName(source.fileName);
      String? path;

      try {
        path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save processed WAV',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: const ['wav'],
        );
      } catch (_) {
        path = null;
      }

      path ??= _fallbackExportPath(source.filePath, defaultFileName);

      if (path == null || path.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isBusy = false;
          _statusMessage = 'Export canceled.';
        });
        return;
      }

      final output = File(path);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(processed.wavBytes, flush: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBusy = false;
        _statusMessage = 'Processed WAV exported to ${output.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
        _statusMessage = 'Export failed: $error';
      });
    }
  }

  String _buildLoadedStatus(AudioData source, ProcessedAudio processed) {
    final decodeKind = source.isExactDecode ? 'exact' : 'estimated';
    return 'Loaded ${source.fileName} (${source.sampleRate} Hz, ${source.channels} ch, '
        '$decodeKind decode). Processed at ${processed.sampleRate} Hz.';
  }

  String _buildReprocessedStatus(AudioData source, ProcessedAudio processed) {
    return 'Reprocessed ${source.fileName} -> ${processed.sampleRate} Hz '
        '(${processed.samples.length} samples).';
  }

  String _buildExportFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final baseName = dot <= 0 ? fileName : fileName.substring(0, dot);
    return '${baseName}_processed.wav';
  }

  String? _fallbackExportPath(String inputPath, String fileName) {
    try {
      final sourceFile = File(inputPath);
      final directory = sourceFile.parent;
      if (!directory.existsSync()) {
        return null;
      }

      final dot = fileName.lastIndexOf('.');
      final base = dot <= 0 ? fileName : fileName.substring(0, dot);
      final extension = dot <= 0 ? 'wav' : fileName.substring(dot + 1);
      var candidate = File('${directory.path}/$fileName');
      var index = 2;
      while (candidate.existsSync()) {
        candidate = File('${directory.path}/${base}_$index.$extension');
        index += 1;
      }
      return candidate.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final waveformSamples = _processedAudio?.samples ?? _audioData?.samples ?? const <double>[];
    final waveformDuration = _processedAudio?.duration ?? _audioData?.duration ?? Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Curvora Audio Analyzer'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1080) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 380,
                      child: ControlPanel(
                        audioData: _audioData,
                        settings: _settings,
                        isBusy: _isBusy,
                        isPlaying: _isPlaying,
                        isPlayingProcessed: _isPlayingProcessed,
                        statusMessage: _statusMessage,
                        onPickFile: _pickFile,
                        onSettingsChanged: _onSettingsChanged,
                        onPlayOriginal: _playOriginal,
                        onPlayProcessed: _playProcessed,
                        onPauseOrResume: _pauseOrResume,
                        onStop: _stopPlayback,
                        onExport: _exportProcessedWav,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _AnalysisPanels(
                        waveformSamples: waveformSamples,
                        waveformDuration: waveformDuration,
                        showSamplePoints: _settings.showSamplePoints,
                        spectrogram: _spectrogram,
                        isBusy: _isBusy,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: ControlPanel(
                      audioData: _audioData,
                      settings: _settings,
                      isBusy: _isBusy,
                      isPlaying: _isPlaying,
                      isPlayingProcessed: _isPlayingProcessed,
                      statusMessage: _statusMessage,
                      onPickFile: _pickFile,
                      onSettingsChanged: _onSettingsChanged,
                      onPlayOriginal: _playOriginal,
                      onPlayProcessed: _playProcessed,
                      onPauseOrResume: _pauseOrResume,
                      onStop: _stopPlayback,
                      onExport: _exportProcessedWav,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 7,
                    child: _AnalysisPanels(
                      waveformSamples: waveformSamples,
                      waveformDuration: waveformDuration,
                      showSamplePoints: _settings.showSamplePoints,
                      spectrogram: _spectrogram,
                      isBusy: _isBusy,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnalysisPanels extends StatelessWidget {
  const _AnalysisPanels({
    required this.waveformSamples,
    required this.waveformDuration,
    required this.showSamplePoints,
    required this.spectrogram,
    required this.isBusy,
  });

  final List<double> waveformSamples;
  final Duration waveformDuration;
  final bool showSamplePoints;
  final List<List<double>> spectrogram;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Waveform',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: WaveformView(
                            samples: waveformSamples,
                            duration: waveformDuration,
                            showSamplePoints: showSamplePoints,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isBusy)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Color(0x660D121B),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Spectrogram',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SpectrogramView(spectrogram: spectrogram),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
