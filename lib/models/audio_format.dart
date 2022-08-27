enum AudioFormat {
  unknown(name: 'unknown'),
  trueHD(name: 'Dolby TrueHD'),
  dtsHDMA(name: 'DTS-HD Master Audio'),
  dolbyDigitalPlus(name: 'Dolby Digital Plus'),
  dolbyDigital(name: 'Dolby Digital'),
  dtsX(name: 'DTS:X'),
  dts(name: 'DTS'),
  aacMulti(name: 'AAC multichannel'),
  stereo(name: 'stereo'),
  mono(name: 'mono');

  const AudioFormat({required this.name});

  final String name;

  @override
  String toString() => name;

  static AudioFormat fromAacSubType(int? channels) {
    if (channels != null) {
      if (channels >= 5) {
        return AudioFormat.aacMulti;
      } else if (channels == 2) {
        return AudioFormat.stereo;
      } else if (channels == 1) {
        return AudioFormat.mono;
      }
    }
    return AudioFormat.stereo;
  }
}
