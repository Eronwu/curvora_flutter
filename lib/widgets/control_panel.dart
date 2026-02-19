import 'package:curvora_flutter/models/audio_data.dart';
import 'package:curvora_flutter/models/processing_settings.dart';
import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.audioData,
    required this.settings,
    required this.isBusy,
    required this.isPlaying,
    required this.isPlayingProcessed,
    required this.statusMessage,
    required this.onPickFile,
    required this.onSettingsChanged,
    required this.onPlayOriginal,
    required this.onPlayProcessed,
    required this.onPauseOrResume,
    required this.onStop,
    required this.onExport,
  });

  final AudioData? audioData;
  final ProcessingSettings settings;
  final bool isBusy;
  final bool isPlaying;
  final bool isPlayingProcessed;
  final String? statusMessage;
  final VoidCallback onPickFile;
  final ValueChanged<ProcessingSettings> onSettingsChanged;
  final VoidCallback onPlayOriginal;
  final VoidCallback onPlayProcessed;
  final VoidCallback onPauseOrResume;
  final VoidCallback onStop;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final disabled = audioData == null || isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : onPickFile,
                    icon: const Icon(Icons.audio_file_rounded),
                    label: const Text('Load audio file'),
                  ),
                ),
              ],
            ),
            if (statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                statusMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFA7BDD4),
                    ),
              ),
            ],
            const SizedBox(height: 18),
            _SectionTitle(title: 'Audio Info'),
            _AudioInfoCard(audioData: audioData),
            const SizedBox(height: 16),
            _SectionTitle(title: 'Processing Controls'),
            const SizedBox(height: 8),
            _LabeledSlider(
              label: 'Gain',
              value: settings.gain,
              min: 0,
              max: 3,
              divisions: 300,
              enabled: !disabled,
              onChanged: (value) => onSettingsChanged(settings.copyWith(gain: value)),
            ),
            _LabeledSlider(
              label: 'Clipping Threshold',
              value: settings.clippingThreshold,
              min: 0.05,
              max: 1,
              divisions: 190,
              enabled: !disabled,
              onChanged: (value) => onSettingsChanged(settings.copyWith(clippingThreshold: value)),
            ),
            const SizedBox(height: 8),
            Text('Target sample rate', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: settings.targetSampleRate,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: ProcessingSettings.supportedSampleRates
                  .map(
                    (rate) => DropdownMenuItem<int>(
                      value: rate,
                      child: Text(_formatRate(rate)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: disabled
                  ? null
                  : (rate) {
                      if (rate == null) {
                        return;
                      }
                      onSettingsChanged(settings.copyWith(targetSampleRate: rate));
                    },
            ),
            const SizedBox(height: 14),
            Text('Resampling algorithm', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<ResamplingAlgorithm>(
              segments: const [
                ButtonSegment(value: ResamplingAlgorithm.linear, label: Text('linear')),
                ButtonSegment(value: ResamplingAlgorithm.sinc, label: Text('sinc')),
              ],
              selected: {settings.resamplingAlgorithm},
              showSelectedIcon: false,
              onSelectionChanged: disabled
                  ? null
                  : (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      onSettingsChanged(
                        settings.copyWith(resamplingAlgorithm: selection.first),
                      );
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: settings.showSamplePoints,
              onChanged: disabled
                  ? null
                  : (value) {
                      onSettingsChanged(settings.copyWith(showSamplePoints: value));
                    },
              title: const Text('Show sample points'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 28),
            _SectionTitle(title: 'Playback Preview'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: disabled ? null : onPlayOriginal,
                  icon: const Icon(Icons.library_music_rounded),
                  label: const Text('Original'),
                ),
                FilledButton.tonalIcon(
                  onPressed: disabled ? null : onPlayProcessed,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Processed'),
                ),
                FilledButton.tonalIcon(
                  onPressed: disabled ? null : onPauseOrResume,
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                ),
                FilledButton.tonalIcon(
                  onPressed: disabled ? null : onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPlaying
                  ? (isPlayingProcessed ? 'Playing processed preview' : 'Playing original file')
                  : 'Playback idle',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF9DB1CA)),
            ),
            const Divider(height: 28),
            FilledButton.icon(
              onPressed: disabled ? null : onExport,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Export processed WAV'),
            ),
            if (audioData != null && !audioData!.isExactDecode) ...[
              const SizedBox(height: 10),
              Text(
                'Compressed input was metadata-estimated. For exact sample analysis, use WAV input.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFC08A),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRate(int value) {
    if (value >= 1000) {
      final khz = value / 1000;
      final printable = khz == khz.roundToDouble() ? khz.toStringAsFixed(0) : khz.toStringAsFixed(2);
      return '$printable kHz';
    }
    return '$value Hz';
  }
}

class _AudioInfoCard extends StatelessWidget {
  const _AudioInfoCard({required this.audioData});

  final AudioData? audioData;

  @override
  Widget build(BuildContext context) {
    final data = audioData;
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      margin: const EdgeInsets.only(top: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _InfoRow(label: 'Filename', value: data?.fileName ?? '—', style: textStyle),
            _InfoRow(label: 'Duration', value: _formatDuration(data?.duration), style: textStyle),
            _InfoRow(label: 'Sample rate', value: _formatRate(data?.sampleRate), style: textStyle),
            _InfoRow(label: 'Channels', value: data?.channels.toString() ?? '—', style: textStyle),
            _InfoRow(label: 'Sample count', value: _formatInt(data?.sampleCount), style: textStyle),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '—';
    }
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRate(int? rate) => rate == null ? '—' : '$rate Hz';

  String _formatInt(int? value) {
    if (value == null) {
      return '—';
    }
    final asString = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < asString.length; index++) {
      final positionFromEnd = asString.length - index;
      buffer.write(asString[index]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
            Text(value.toStringAsFixed(2), style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.style});

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: const Color(0xFF96A9C0)),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: style?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
