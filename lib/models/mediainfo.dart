import 'package:json_annotation/json_annotation.dart';

part 'mediainfo.g.dart';

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
}

int _stringToInt(String? s) => (s == null) ? 0 : int.parse(s);
String _intToString(int? n) => (n == null) ? '' : n.toString();

RegExp _truthyRegEx = RegExp(r'^\s*(yes|true)\s*$', multiLine: true, caseSensitive: false);

bool _stringToBool(String? s) => (s == null) ? false : _truthyRegEx.hasMatch(s);

AudioFormat _aacSubType(int? channels) {
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

@JsonSerializable()
class MediaRoot {
  const MediaRoot(this.media);

  final Media media;

  factory MediaRoot.fromJson(Map<String, dynamic> json) => _$MediaRootFromJson(json);

  Map<String, dynamic> toJson() => _$MediaRootToJson(this);
}

@JsonSerializable()
class Media {
  const Media(this.ref, this.trackList);

  @JsonKey(name: '@ref')
  final String ref;

  @JsonKey(name: 'track')
  final TrackList trackList;

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);

  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

@JsonSerializable()
class TrackList {
  const TrackList(List<Track>? tracks,
      {this.generalTrack,
      List<AudioTrack>? audioTracks,
      List<MenuTrack>? menuTracks,
      List<TextTrack>? textTracks,
      List<VideoTrack>? videoTracks})
      : tracks = tracks ?? const [],
        audioTracks = audioTracks ?? const [],
        menuTracks = menuTracks ?? const [],
        textTracks = textTracks ?? const [],
        videoTracks = videoTracks ?? const [];

  final List<Track> tracks;
  final GeneralTrack? generalTrack;
  final List<AudioTrack> audioTracks;
  final List<MenuTrack> menuTracks;
  final List<TextTrack> textTracks;
  final List<VideoTrack> videoTracks;

  factory TrackList.fromJson(List<dynamic> jsonTracks) {
    GeneralTrack? general;
    var audioTracks = <AudioTrack>[];
    var menuTracks = <MenuTrack>[];
    var textTracks = <TextTrack>[];
    var videoTracks = <VideoTrack>[];

    var tracks = <Track>[];
    for (var e in jsonTracks) {
      var em = e as Map<String, dynamic>;
      Track t;
      if (em['@type'] == 'Audio') {
        t = AudioTrack.fromJson(em);
        audioTracks.add(t as AudioTrack);
      } else if (em['@type'] == 'General') {
        general = GeneralTrack.fromJson(em);
        t = general;
      } else if (em['@type'] == 'Menu') {
        t = MenuTrack.fromJson(em);
        menuTracks.add(t as MenuTrack);
      } else if (em['@type'] == 'Text') {
        t = TextTrack.fromJson(em);
        textTracks.add(t as TextTrack);
      } else if (em['@type'] == 'Video') {
        t = VideoTrack.fromJson(em);
        videoTracks.add(t as VideoTrack);
      } else {
        t = UnknownTrack(em['@type'] ?? 'Unknown');
      }
      tracks.add(t);
    }

    return TrackList(tracks,
        generalTrack: general,
        audioTracks: audioTracks,
        menuTracks: menuTracks,
        textTracks: textTracks,
        videoTracks: videoTracks);
  }

  Map<String, dynamic> toJson() {
    List<dynamic> json = [];
    for (final t in tracks) {
      json.add(t.toJson());
    }
    return {'tracks': json};
  }
}

@JsonSerializable()
class Track {
  const Track();

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class GeneralTrack extends Track {
  @JsonKey(name: "UniqueID")
  final String? uniqueId;
  final String fileExtension;
  final String? format;
  final String? movie;
  final String? title;

  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? audioCount;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? menuCount;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? textCount;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? videoCount;

  @JsonKey(name: 'extra')
  final Map<String, dynamic>? extra;

  const GeneralTrack(this.uniqueId, this.videoCount, this.audioCount, this.textCount,
      this.menuCount, this.fileExtension, this.title, this.movie, this.format, this.extra);

  factory GeneralTrack.fromJson(Map<String, dynamic> json) => _$GeneralTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$GeneralTrackToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class AudioTrack extends Track {
  @JsonKey(name: 'CodecID')
  final String? codecId;
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'Format_AdditionalFeatures')
  final String? formatAdditionalFeatures;
  @JsonKey(name: 'Format_Commercial_IfAny')
  final String? formatCommercialName;
  @JsonKey(name: 'ID')
  final String id;
  @JsonKey(name: '@typeorder', fromJson: _stringToInt, toJson: _intToString)
  final int typeOrder;
  @JsonKey(name: "UniqueID")
  final String? uniqueId;

  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? channels;

  final String? channelPositions;
  final String? channelLayout;
  final String format;
  final String? language;
  final String streamOrder;

  final String? title;

  @JsonKey(name: 'Default', fromJson: _stringToBool)
  final bool isDefault;
  @JsonKey(name: 'Forced', fromJson: _stringToBool)
  final bool isForced;

  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int? bitRate;
  @JsonKey(name: 'BitRate_Mode')
  final String? bitRateMode;
  @JsonKey(name: 'BitRate_Maximum', fromJson: _stringToInt, toJson: _intToString)
  final int? bitRateMax;

  const AudioTrack(
      this.typeOrder,
      this.streamOrder,
      this.id,
      this.uniqueId,
      this.extra,
      this.codecId,
      this.format,
      this.formatCommercialName,
      this.formatAdditionalFeatures,
      this.channels,
      this.channelPositions,
      this.channelLayout,
      this.title,
      this.isDefault,
      this.isForced,
      this.language,
      this.bitRate,
      this.bitRateMode,
      this.bitRateMax);

  AudioFormat get simpleFormat {
    switch (format) {
      case 'MLP FBA':
        return AudioFormat.trueHD;
      case 'E-AC-3':
      case 'E-AC-3 JOC':
        return AudioFormat.dolbyDigitalPlus;
      case 'AC-3':
        return AudioFormat.dolbyDigital;
      // TODO: DTS, DTS:X, DTS-HD MA
    }

    if (format == 'AAC') {
      return _aacSubType(channels);
    }

    if (codecId != null) {
      String codecId = this.codecId!;
      switch (codecId) {
        case 'A_TRUEHD':
          return AudioFormat.trueHD;
        case 'A_AC3':
          return AudioFormat.dolbyDigital;
        case 'A_EAC3':
          return AudioFormat.dolbyDigitalPlus;
        // TODO: DTS, DTS:X, DTS-HD MA
      }

      if (codecId == 'A_AAC-2') {
        return _aacSubType(channels);
      }
    }

    if (formatCommercialName != null) {
      String formatCommercialName = this.formatCommercialName!;
      if (formatCommercialName.contains('Dolby TrueHD')) {
        return AudioFormat.trueHD;
      } else if (formatCommercialName.startsWith('Dolby Digital Plus')) {
        return AudioFormat.dolbyDigitalPlus;
      } else if (formatCommercialName == 'Dolby Digital') {
        return AudioFormat.dolbyDigital;
      }
    }

    return AudioFormat.unknown;
  }

  int? get bitRateLimit => bitRate ?? bitRateMax;

  factory AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$AudioTrackToJson(this);
}

@JsonSerializable()
class MenuTrack extends Track {
  final Map<String, String>? extra;

  const MenuTrack(this.extra);

  factory MenuTrack.fromJson(Map<String, dynamic> json) => _$MenuTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MenuTrackToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class TextTrack extends Track {
  @JsonKey(name: 'CodecID')
  final String? codecId;
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: '@typeorder', fromJson: _stringToInt, toJson: _intToString)
  final int typeOrder;
  @JsonKey(name: 'ID')
  final String id;
  @JsonKey(name: "UniqueID")
  final String? uniqueId;

  final String? format;
  final String? language;
  final String? title;

  @JsonKey(name: 'Default', fromJson: _stringToBool)
  final bool isDefault;
  @JsonKey(name: 'Forced', fromJson: _stringToBool)
  final bool isForced;

  const TextTrack(this.typeOrder, this.id, this.uniqueId, this.extra, this.title, this.language,
      this.isDefault, this.isForced, this.format, this.codecId);

  String get languageName {
    if (language == null) {
      return 'Unknown';
    }
    switch (language) {
      case 'de':
      case 'deu':
        return 'German';
      case 'en':
      case 'eng':
        return 'English';
      case 'es':
      case 'esp':
        return 'Spanish';
      case 'fr':
      case 'fra':
        return 'French';
      default:
        return 'Unknown';
    }
  }

  String get handler {
    var buffer = StringBuffer();
    if (title == null) {
      buffer.write(languageName);
    } else if (title!.contains(languageName)) {
      buffer.write(title);
    } else {
      buffer.write(languageName);
      buffer.write(' $title');
    }
    if ((format != null && format!.startsWith('UTF')) ||
        (codecId != null && codecId!.startsWith('S_TEXT'))) {
      buffer.write(' (SRT)');
    }
    return buffer.toString();
  }

  factory TextTrack.fromJson(Map<String, dynamic> json) => _$TextTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$TextTrackToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class VideoTrack extends Track {
  @JsonKey(name: 'CodecID')
  final String? codecId;
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'HDR_Format')
  final String? hdrFormat;
  @JsonKey(name: 'HDR_Format_Compatibility')
  final String? hdrFormatCompatibility;
  @JsonKey(name: "ID")
  final String id;
  @JsonKey(name: "UniqueID")
  final String? uniqueId;

  final String format;
  final String streamOrder;

  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int height;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int width;

  const VideoTrack(this.streamOrder, this.id, this.uniqueId, this.extra, this.codecId, this.format,
      this.width, this.height, this.hdrFormat, this.hdrFormatCompatibility);

  factory VideoTrack.fromJson(Map<String, dynamic> json) => _$VideoTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$VideoTrackToJson(this);

  bool get isHDR => hdrFormat != null;

  String hdrName() => isHDR ? 'HDR' : 'SDR';

  String get sizeName {
    if (width == 1920) {
      return "1080p";
    } else if (width == 3840) {
      return "2160p";
    }
    return "unknown";
  }
}

class UnknownTrack implements Track {
  final String trackType;

  const UnknownTrack(this.trackType);

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
