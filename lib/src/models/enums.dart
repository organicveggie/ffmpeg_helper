import 'package:json_annotation/json_annotation.dart';

extension EnumAllNames<T extends Enum> on Iterable<T> {
  // ignore: unnecessary_this
  Iterable<String> names() => this.asNameMap().keys;
}

extension EnumByNameOrNull<T extends Enum> on Iterable<T> {
  T? byNameNullable(String? name) {
    for (var value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}

extension EnumByNameWithDefault<T extends Enum> on Iterable<T> {
  T byNameDefault(String name, T defaultValue) {
    for (var value in this) {
      if (value.name == name) return value;
    }
    return defaultValue;
  }
}

enum AudioFormat {
  unknown(name: 'unknown', codecId: 'unknown', codec: 'unknown', format: 'unknown'),
  trueHD(name: 'Dolby TrueHD', codecId: 'A_TRUEHD', codec: 'truehd', format: 'MLP FBA'),
  dtsHDMA(name: 'DTS-HD MA', codecId: 'A_DTS', codec: 'dts', format: 'DTS'),
  dolbyDigitalPlus(name: 'Dolby Digital Plus', codecId: 'A_EAC3', codec: 'eac3', format: 'E-AC-3'),
  dolbyDigital(name: 'Dolby Digital', codecId: 'A_AC3', codec: 'ac3', format: 'AC-3'),
  dtsX(name: 'DTS:X', codecId: 'A_DTS', codec: 'dts', format: 'DTS'),
  dts(name: 'DTS', codecId: 'A_DTS', codec: 'dts', format: 'DTS'),
  aacMulti(name: 'AAC multichannel', codecId: 'A_AAC-2', codec: 'aac', format: 'AAC'),
  stereo(name: 'stereo', codecId: 'A_AAC-2', codec: 'aac', format: 'AAC'),
  mono(name: 'mono', codecId: 'A_AAC-2', codec: 'aac', format: 'AAC');

  const AudioFormat(
      {required this.name, required this.codecId, required this.codec, required this.format});

  final String codecId;
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
}

enum OutputFileMode {
  append,
  fail,
  overwrite;

  String get name {
    final String description = toString();
    final int indexOfDot = description.indexOf('.');
    assert(indexOfDot != -1 && indexOfDot < description.length - 1);
    return description.substring(indexOfDot + 1);
  }
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
  hd({'1080', '1080p'}),
  uhd({'4k', '2160', '2160p'});

  final Set<String> aliases;

  const VideoResolution(this.aliases);

  String toSizeName() {
    switch (this) {
      case hd:
        return '1080p';
      case uhd:
        return '2160p';
    }
  }

  static Iterable<String> namesAndAliases() {
    var all = <String>[];
    for (var v in VideoResolution.values) {
      all.add(v.name);
      all.addAll(v.aliases);
    }
    all.sort();
    return all;
  }

  static VideoResolution? byNameOrAlias(String? name) {
    for (var v in values) {
      if (v.name == name || v.aliases.contains(name)) {
        return v;
      }
    }
    return null;
  }
}
