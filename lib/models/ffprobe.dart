import 'package:built_collection/built_collection.dart';
import 'package:json_annotation/json_annotation.dart';

import 'audio_format.dart';

part 'ffprobe.g.dart';

class FfprobeJsonException implements Exception {
  final String message;

  FfprobeJsonException(this.message);

  @override
  String toString() => message;
}

@JsonEnum(fieldRename: FieldRename.snake)
enum CodecType {
  audio,
  subtitle,
  video,
  unknown;
}

@JsonSerializable()
class Media {
  final List<Stream> streams;

  final List<AudioStream> audioStreams;
  final List<TextStream> subtitleStreams;
  final List<VideoStream> videoStreams;

  const Media(this.streams,
      {List<AudioStream>? audios, List<TextStream>? subtitles, List<VideoStream>? videos})
      : audioStreams = audios ?? const [],
        subtitleStreams = subtitles ?? const [],
        videoStreams = videos ?? const [];

  factory Media.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('streams')) {
      throw FfprobeJsonException('Missing "streams" field.');
    }

    var allStreams = <Stream>[];
    var audioStreams = <AudioStream>[];
    var subtitleStreams = <TextStream>[];
    var videoStreams = <VideoStream>[];

    List<dynamic> streamsJson = json['streams'];
    for (var s in streamsJson) {
      var stream = Stream.fromJson(s);
      switch (stream.codecType) {
        case CodecType.audio:
          var audio = AudioStream.fromJson(s);
          audioStreams.add(audio);
          allStreams.add(audio);
          break;
        case CodecType.subtitle:
          var subtitle = TextStream.fromJson(s);
          subtitleStreams.add(subtitle);
          allStreams.add(subtitle);
          break;
        case CodecType.video:
          var video = VideoStream.fromJson(s);
          videoStreams.add(video);
          allStreams.add(video);
          break;
        default:
          throw FfprobeJsonException('Unknown codec_type for stream ${stream.index}.');
      }
    }

    return Media(allStreams,
        audios: audioStreams, subtitles: subtitleStreams, videos: videoStreams);
  }

  Map<String, dynamic> toJson() => _$MediaToJson(this);
}

@JsonSerializable()
class Stream {
  final int index;
  @JsonKey(name: 'codec_type')
  final CodecType codecType;
  @JsonKey(name: 'codec_name')
  final String codecName;
  @JsonKey(name: 'codec_long_name')
  final String codecLongName;

  final Disposition? disposition;
  final StreamTags? tags;

  const Stream(
    this.index,
    this.codecType,
    this.codecName,
    this.codecLongName,
    this.disposition,
    this.tags,
  );

  factory Stream.fromJson(Map<String, dynamic> json) => _$StreamFromJson(json);
  Map<String, dynamic> toJson() => _$StreamToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AudioStream extends Stream {
  final String? channelLayout;
  final int? channels;

  @JsonKey(fromJson: _stringToNullableInt, toJson: _intToString)
  final int? sampleRate;

  @JsonKey(fromJson: _stringToNullableInt, toJson: _intToString)
  final int? bitRate;

  @JsonKey(fromJson: _stringToNullableInt, toJson: _intToString)
  final int? maxBitRate;

  AudioStream(
      super.index,
      super.codecType,
      super.codecName,
      super.codecLongName,
      super.disposition,
      super.tags,
      this.sampleRate,
      this.channels,
      this.channelLayout,
      this.bitRate,
      this.maxBitRate);

  factory AudioStream.fromJson(Map<String, dynamic> json) => _$AudioStreamFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$AudioStreamToJson(this);

  int? get bitRateKbps => (bitRate == null) ? null : bitRate! ~/ 1000;
  int? get maxBitRateKbps => (maxBitRate == null) ? null : maxBitRate! ~/ 1000;

  static final BuiltMap<String, AudioFormat> codecToFormat = BuiltMap.of(<String, AudioFormat>{
    'ac3': AudioFormat.dolbyDigital,
    'dts': AudioFormat.dts,
    'eac3': AudioFormat.dolbyDigitalPlus,
    'truehd': AudioFormat.trueHD,
  });

  AudioFormat toAudioFormat() {
    if (codecToFormat.containsKey(codecName)) {
      return codecToFormat[codecName]!;
    }

    if (codecName == "aac") {
      return AudioFormat.fromAacSubType(channels);
    }

    // TODO: DTS:X, DTS-HD MA

    return AudioFormat.unknown;
  }
}

@JsonSerializable()
class TextStream extends Stream {
  const TextStream(super.index, super.codecType, super.codecName, super.codecLongName,
      super.disposition, super.tags);

  factory TextStream.fromJson(Map<String, dynamic> json) => _$TextStreamFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$TextStreamToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class VideoStream extends Stream {
  static const aribColorTransfer = 'arib-std-b67';
  static const smpte2084ColorTransfer = 'smpte2084';

  final int height;
  final int width;

  final String? colorSpace;
  final String? colorTransfer;
  final String? colorPrimaries;

  const VideoStream(
      super.index,
      super.codecType,
      super.codecName,
      super.codecLongName,
      super.disposition,
      super.tags,
      this.height,
      this.width,
      this.colorSpace,
      this.colorTransfer,
      this.colorPrimaries);

  factory VideoStream.fromJson(Map<String, dynamic> json) => _$VideoStreamFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$VideoStreamToJson(this);

  bool get isHDR {
    return (colorTransfer != null) &&
        ((colorTransfer == aribColorTransfer) || (colorTransfer == smpte2084ColorTransfer));
  }

  String get hdrName => isHDR ? 'HDR' : 'SDR';

  String get sizeName {
    if (width == 1920) {
      return "1080p";
    } else if (width == 3840) {
      return "2160p";
    }
    return "unknown";
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Disposition {
  @JsonKey(name: 'default', fromJson: _intToBool, toJson: _boolToInt)
  final bool def;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool dub;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool forced;
  @JsonKey(fromJson: _intToBool, toJson: _boolToInt)
  final bool original;

  bool get isDefault => def;

  const Disposition(this.def, this.dub, this.forced, this.original);

  factory Disposition.fromJson(Map<String, dynamic> json) => _$DispositionFromJson(json);
  Map<String, dynamic> toJson() => _$DispositionToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StreamTags {
  final String? comment;
  final String? encoder;
  final String? handlerName;
  final String? language;
  final String? title;

  const StreamTags(this.comment, this.encoder, this.handlerName, this.language, this.title);

  factory StreamTags.fromJson(Map<String, dynamic> json) => _$StreamTagsFromJson(json);
  Map<String, dynamic> toJson() => _$StreamTagsToJson(this);
}

int _stringToInt(String? s) => (s == null) ? 0 : int.parse(s);
String _intToString(int? n) => (n == null) ? '' : n.toString();

int? _stringToNullableInt(String? s) => (s == null) ? null : int.parse(s);

bool _intToBool(int? n) => (n != null) && (n == 1);
int _boolToInt(bool b) => b ? 1 : 0;
