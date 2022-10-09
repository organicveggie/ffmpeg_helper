import 'package:json_annotation/json_annotation.dart';

enum AudioFormat {
  unknown(name: 'unknown'),
  trueHD(name: 'Dolby TrueHD'),
  dtsHDMA(name: 'DTS-HD MA'),
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

enum BitRateMode {
  constant('CBR'),
  variable('VBR'),
  unknown('unknown');

  const BitRateMode(this.name);

  final String name;

  @override
  String toString() => name;
}

enum MediaType {
  movie,
  tv;

  static Iterable<String> names() => MediaType.values.map((v) => v.name);
}

@JsonEnum(fieldRename: FieldRename.pascal)
enum TrackType { audio, general, menu, text, video }

enum VideoResolution {
  hd(['1080', '1080p']),
  uhd(['4k', '2160', '2160p']);

  final List<String> aliases;

  const VideoResolution(this.aliases);

  static Iterable<String> names() => VideoResolution.values.map((v) => v.name);
  static Iterable<String> allNames() {
    var all = <String>[];
    for (var v in VideoResolution.values) {
      all.add(v.name);
      all.addAll(v.aliases);
    }
    all.sort();
    return all;
  }
}
