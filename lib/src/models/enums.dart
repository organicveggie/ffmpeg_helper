import 'package:json_annotation/json_annotation.dart';

enum AudioFormat {
  unknown(name: 'unknown', codec: 'unknown', format: 'unknown'),
  trueHD(name: 'Dolby TrueHD', codec: 'A_TRUEHD', format: 'MLP FBA'),
  dtsHDMA(name: 'DTS-HD MA', codec: 'A_DTS', format: 'DTS'),
  dolbyDigitalPlus(name: 'Dolby Digital Plus', codec: 'A_EAC3', format: 'A_EAC3'),
  dolbyDigital(name: 'Dolby Digital', codec: 'A_AC3', format: 'A_AC3'),
  dtsX(name: 'DTS:X', codec: 'A_DTS', format: 'DTS'),
  dts(name: 'DTS', codec: 'A_DTS', format: 'DTS'),
  aacMulti(name: 'AAC multichannel', codec: 'A_AAC-2', format: 'AAC'),
  stereo(name: 'stereo', codec: 'A_AAC-2', format: 'AAC'),
  mono(name: 'mono', codec: 'A_AAC-2', format: 'AAC');

  const AudioFormat({required this.name, required this.codec, required this.format});

  final String codec;
  final String format;
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
enum TrackType {
  audio('a'),
  general('g'),
  menu('m'),
  text('s'),
  video('v');

  final String abbrev;

  const TrackType(this.abbrev);
}

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
