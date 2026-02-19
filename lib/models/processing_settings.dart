enum ResamplingAlgorithm { linear, sinc }

class ProcessingSettings {
  const ProcessingSettings({
    this.gain = 1.0,
    this.clippingThreshold = 1.0,
    this.targetSampleRate = 44100,
    this.resamplingAlgorithm = ResamplingAlgorithm.linear,
    this.showSamplePoints = false,
  });

  static const supportedSampleRates = <int>[
    8000,
    16000,
    22050,
    44100,
    48000,
    88200,
    96000,
    176400,
    192000,
  ];

  final double gain;
  final double clippingThreshold;
  final int targetSampleRate;
  final ResamplingAlgorithm resamplingAlgorithm;
  final bool showSamplePoints;

  ProcessingSettings copyWith({
    double? gain,
    double? clippingThreshold,
    int? targetSampleRate,
    ResamplingAlgorithm? resamplingAlgorithm,
    bool? showSamplePoints,
  }) {
    return ProcessingSettings(
      gain: gain ?? this.gain,
      clippingThreshold: clippingThreshold ?? this.clippingThreshold,
      targetSampleRate: targetSampleRate ?? this.targetSampleRate,
      resamplingAlgorithm: resamplingAlgorithm ?? this.resamplingAlgorithm,
      showSamplePoints: showSamplePoints ?? this.showSamplePoints,
    );
  }
}
