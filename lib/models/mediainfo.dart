import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'audio_format.dart';

part 'mediainfo.g.dart';

enum BitRateMode {
  constant('CBR'),
  variable('VBR'),
  unknown('unknown');

  const BitRateMode(this.name);

  final String name;

  @override
  String toString() => name;
}

@JsonEnum(fieldRename: FieldRename.pascal)
enum TrackType { audio, general, menu, text, video }

@JsonSerializable()
class MediaRoot with EquatableMixin {
  const MediaRoot(this.media);

  final Media media;

  factory MediaRoot.fromJson(Map<String, dynamic> json) => _$MediaRootFromJson(json);

  Map<String, dynamic> toJson() => _$MediaRootToJson(this);

  @override
  List<Object?> get props => [media];
}

@JsonSerializable()
class Media with EquatableMixin {
  const Media(this.ref, this.trackList);

  @JsonKey(name: '@ref')
  final String ref;

  @JsonKey(name: 'track')
  final TrackList trackList;

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);

  Map<String, dynamic> toJson() => _$MediaToJson(this);

  @override
  List<Object?> get props => [ref, trackList];
}

@JsonSerializable()
class TrackList with EquatableMixin {
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

    for (var e in jsonTracks) {
      var em = e as Map<String, dynamic>;
      var t = Track.fromJson(em);
      switch (t.type) {
        case TrackType.audio:
          audioTracks.add(AudioTrack.fromJson(em));
          break;
        case TrackType.general:
          general = GeneralTrack.fromJson(em);
          break;
        case TrackType.menu:
          menuTracks.add(MenuTrack.fromJson(em));
          break;
        case TrackType.text:
          textTracks.add(TextTrack.fromJson(em));
          break;
        case TrackType.video:
          videoTracks.add(VideoTrack.fromJson(em));
          break;
      }
    }

    var tracks = <Track>[
      ...videoTracks,
      ...audioTracks,
      ...textTracks,
      ...menuTracks,
    ];
    if (general != null) {
      tracks.add(general);
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

  @override
  List<Object?> get props => [tracks];
}

@JsonSerializable()
class Track with EquatableMixin {
  @JsonKey(name: '@type')
  final TrackType type;

  const Track(this.type);

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  @override
  List<Object?> get props => [type];
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class GeneralTrack extends Track with EquatableMixin {
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

  const GeneralTrack(super.type, this.uniqueId, this.videoCount, this.audioCount, this.textCount,
      this.menuCount, this.fileExtension, this.title, this.movie, this.format, this.extra);

  factory GeneralTrack.fromJson(Map<String, dynamic> json) => _$GeneralTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$GeneralTrackToJson(this);

  @override
  List<Object?> get props =>
      [uniqueId, fileExtension, format, movie, audioCount, menuCount, textCount, videoCount, extra];
}

@JsonSerializable()
class CodecIdTrack extends Track with EquatableMixin {
  @JsonKey(name: 'ID')
  final String id;
  @JsonKey(name: 'CodecID')
  final String codecId;
  @JsonKey(name: "UniqueID")
  final String? uniqueId;

  const CodecIdTrack(super.type, this.id, this.codecId, this.uniqueId);

  factory CodecIdTrack.fromJson(Map<String, dynamic> json) => _$CodecIdTrackFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CodecIdTrackToJson(this);

  @override
  List<Object?> get props => [id, codecId, uniqueId];
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class AudioTrack extends CodecIdTrack with EquatableMixin {
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'Format_AdditionalFeatures')
  final String? formatAdditionalFeatures;
  @JsonKey(name: 'Format_Commercial_IfAny')
  final String? formatCommercialName;
  @JsonKey(name: '@typeorder', fromJson: _stringToInt, toJson: _intToString)
  final int typeOrder;

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
  @JsonKey(name: 'BitRate_Mode', fromJson: _stringToBitRateMode, toJson: _bitRateModeToString)
  final BitRateMode? bitRateMode;
  @JsonKey(name: 'BitRate_Maximum', fromJson: _stringToInt, toJson: _intToString)
  final int? bitRateMax;

  final String? compressionMode;

  const AudioTrack(
      super.type,
      super.id,
      super.codecId,
      super.uniqueId,
      this.typeOrder,
      this.streamOrder,
      this.extra,
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
      this.bitRateMax,
      this.compressionMode);

  factory AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);
  factory AudioTrack.fromMinimal(
      String id, int typeOrder, String streamOrder, String codecId, String format, int channels) {
    return AudioTrack(TrackType.audio, id, codecId, null, typeOrder, streamOrder, null, format,
        null, null, channels, null, null, null, false, false, null, null, null, null, null);
  }
  factory AudioTrack.fromParams(
      {required String id,
      required String codecId,
      String? uniqueId,
      required int typeOrder,
      required String streamOrder,
      Map<String, String>? extra,
      required String format,
      String? formatCommercialName,
      String? formatAdditionalFeatures,
      int? channels,
      String? channelPositions,
      String? channelLayout,
      String? title,
      required bool isDefault,
      required bool isForced,
      String? language,
      int? bitRate,
      BitRateMode? bitRateMode,
      int? bitRateMax,
      String? compressionMode}) {
    return AudioTrack(
        TrackType.audio,
        id,
        codecId,
        uniqueId,
        typeOrder,
        streamOrder,
        extra,
        format,
        formatCommercialName,
        formatAdditionalFeatures,
        channels,
        channelPositions,
        channelLayout,
        title,
        isDefault,
        isForced,
        language,
        bitRate,
        bitRateMode,
        bitRateMax,
        compressionMode);
  }

  @override
  Map<String, dynamic> toJson() => _$AudioTrackToJson(this);

  @override
  List<Object?> get props => [
        id,
        codecId,
        uniqueId,
        typeOrder,
        streamOrder,
        extra,
        format,
        formatCommercialName,
        formatAdditionalFeatures,
        channels,
        channelPositions,
        channelLayout,
        title,
        isDefault,
        language,
        bitRate,
        bitRateMode,
        bitRateMax,
        compressionMode
      ];

  AudioFormat toAudioFormat() {
    switch (format) {
      case 'MLP FBA':
        return AudioFormat.trueHD;
      case 'E-AC-3':
      case 'E-AC-3 JOC':
        return AudioFormat.dolbyDigitalPlus;
      case 'AC-3':
        return AudioFormat.dolbyDigital;
      case 'AAC':
        return AudioFormat.fromAacSubType(channels);
    }

    switch (codecId) {
      case 'A_TRUEHD':
        return AudioFormat.trueHD;
      case 'A_AC3':
        return AudioFormat.dolbyDigital;
      case 'A_EAC3':
        return AudioFormat.dolbyDigitalPlus;
      case 'A_AAC-2':
        return AudioFormat.fromAacSubType(channels);
    }

    if ((format == 'DTS') || (codecId == 'A_DTS')) {
      if ((formatCommercialName == 'DTS-HD Master Audio') || (isLossless != null && isLossless!)) {
        return AudioFormat.dtsHDMA;
      }
      // TODO: DTS-X vs DTS
      return AudioFormat.dts;
    }

    if (formatCommercialName != null) {
      String formatCommercialName = this.formatCommercialName!;
      if (formatCommercialName.contains('Dolby TrueHD')) {
        return AudioFormat.trueHD;
      } else if (formatCommercialName.startsWith('Dolby Digital Plus')) {
        return AudioFormat.dolbyDigitalPlus;
      } else if (formatCommercialName == 'Dolby Digital') {
        return AudioFormat.dolbyDigital;
      } else if (formatCommercialName == 'DTS-HD Master Audio') {
        return AudioFormat.dtsHDMA;
      }
    }

    return AudioFormat.unknown;
  }

  String? get bitRateAsKbpsOrMode =>
      (bitRateMode == BitRateMode.variable) ? 'VBR' : bitRateAsKbps?.toString();
  int? get bitRateAsKbps => (bitRate == null) ? null : bitRate! ~/ 1000;
  int? get bitRateLimit => bitRate ?? bitRateMax;
  int? get bitRateMaxAsKbps => (bitRateMax == null) ? null : bitRateMax! ~/ 1000;

  bool? get isLossless {
    if (compressionMode == null) {
      return null;
    }
    if (compressionMode?.toLowerCase() == 'lossless') {
      return true;
    }
    return false;
  }
}

@JsonSerializable()
class MenuTrack extends Track with EquatableMixin {
  final Map<String, String>? extra;

  const MenuTrack(super.type, this.extra);

  factory MenuTrack.fromJson(Map<String, dynamic> json) => _$MenuTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$MenuTrackToJson(this);

  @override
  List<Object?> get props => [extra];
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class TextTrack extends Track with EquatableMixin {
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
  final String language;
  final String? title;

  @JsonKey(name: 'Default', fromJson: _stringToBool)
  final bool isDefault;
  @JsonKey(name: 'Forced', fromJson: _stringToBool)
  final bool isForced;

  const TextTrack(super.type, this.typeOrder, this.id, this.uniqueId, this.extra, this.title,
      this.language, this.isDefault, this.isForced, this.format, this.codecId);

  factory TextTrack.fromJson(Map<String, dynamic> json) => _$TextTrackFromJson(json);

  factory TextTrack.fromMinimum(
      int typeOrder, String id, String language, bool isDefault, bool isForced) {
    return TextTrack(
        TrackType.text, typeOrder, id, null, null, null, language, isDefault, isForced, null, null);
  }

  @override
  Map<String, dynamic> toJson() => _$TextTrackToJson(this);

  @override
  List<Object?> get props =>
      [codecId, typeOrder, id, uniqueId, extra, format, language, title, isDefault, isForced];

  String get languageName {
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

  @override
  String toString() => 'Text: $handler';
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class VideoTrack extends CodecIdTrack with EquatableMixin {
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'HDR_Format')
  final String? hdrFormat;
  @JsonKey(name: 'HDR_Format_Compatibility')
  final String? hdrFormatCompatibility;

  final String format;
  final String streamOrder;

  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int height;
  @JsonKey(fromJson: _stringToInt, toJson: _intToString)
  final int width;

  const VideoTrack(
      super.type,
      super.id,
      super.codecId,
      super.uniqueId,
      this.streamOrder,
      this.extra,
      this.format,
      this.width,
      this.height,
      this.hdrFormat,
      this.hdrFormatCompatibility);

  const VideoTrack.create(
      String id,
      String codecId,
      String? uniqueId,
      String streamOrder,
      Map<String, String>? extra,
      String format,
      int width,
      int height,
      String? hdrFormat,
      String? hdrFormatCompatibility)
      : this(TrackType.video, id, codecId, uniqueId, streamOrder, extra, format, width, height,
            hdrFormat, hdrFormatCompatibility);

  factory VideoTrack.fromJson(Map<String, dynamic> json) => _$VideoTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$VideoTrackToJson(this);

  bool get isHDR => hdrFormat != null;
  String get hdrName => isHDR ? 'HDR' : 'SDR';

  String get sizeName {
    if (width == 1920) {
      return "1080p";
    } else if (width == 3840) {
      return "2160p";
    }
    return "unknown";
  }

  @override
  List<Object?> get props => [
        id,
        codecId,
        uniqueId,
        streamOrder,
        extra,
        format,
        width,
        height,
        hdrFormat,
        hdrFormatCompatibility
      ];
}

int _stringToInt(String? s) => (s == null) ? 0 : int.parse(s);
String _intToString(int? n) => (n == null) ? '' : n.toString();

final RegExp _truthyRegEx = RegExp(r'^\s*(yes|true)\s*$', multiLine: true, caseSensitive: false);

bool _stringToBool(String? s) => (s == null) ? false : _truthyRegEx.hasMatch(s);

BitRateMode? _stringToBitRateMode(String? s) {
  if (s == null) {
    return null;
  } else if (s.toUpperCase() == 'CBR') {
    return BitRateMode.constant;
  } else if (s.toUpperCase() == 'VBR') {
    return BitRateMode.variable;
  }
  return BitRateMode.unknown;
}

String? _bitRateModeToString(BitRateMode? mode) => mode?.toString();
