import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_helper/models.dart';

part 'conversions.g.dart';

abstract class StreamOption {
  @override
  String toString();
}

abstract class MapStreamSelection extends StreamOption {
  int get srcStreamId;
  int get dstStreamId;

  int get inputFileId;
}

abstract class StreamCopy
    with EquatableMixin
    implements MapStreamSelection, Built<StreamCopy, StreamCopyBuilder> {
  StreamCopy._();
  factory StreamCopy([void Function(StreamCopyBuilder) updates]) = _$StreamCopy;

  TrackType get trackType;

  @override
  List<Object> get props => [inputFileId, srcStreamId, dstStreamId, trackType];

  @override
  String toString() {
    return '-map $inputFileId:${trackType.abbrev}:$srcStreamId '
        '-c:${trackType.abbrev}:$dstStreamId copy';
  }
}

abstract class BaseAudioStreamConvert implements MapStreamSelection {
  int get channels;
  AudioFormat get format;
  int get kbRate;
}

abstract class AudioStreamConvert
    with EquatableMixin
    implements BaseAudioStreamConvert, Built<AudioStreamConvert, AudioStreamConvertBuilder> {
  AudioStreamConvert._();
  factory AudioStreamConvert([void Function(AudioStreamConvertBuilder) updates]) =
      _$AudioStreamConvert;

  @override
  List<Object> get props => [inputFileId, srcStreamId, dstStreamId, channels, format, kbRate];

  @override
  String toString() {
    return '-map $inputFileId:a:$srcStreamId -c:a:$dstStreamId ${format.codec} -b:a ${kbRate}k '
        '-ac:a:$dstStreamId $channels';
  }
}

abstract class DolbyProLogicAudioStreamConvert
    with EquatableMixin
    implements
        BaseAudioStreamConvert,
        Built<DolbyProLogicAudioStreamConvert, DolbyProLogicAudioStreamConvertBuilder> {
  DolbyProLogicAudioStreamConvert._();
  factory DolbyProLogicAudioStreamConvert(
          [void Function(DolbyProLogicAudioStreamConvertBuilder) updates]) =
      _$DolbyProLogicAudioStreamConvert;

  @override
  List<Object> get props => [inputFileId, srcStreamId, dstStreamId, channels, format, kbRate];

  @override
  String toString() {
    return '-map:a:$srcStreamId "[a]" -c:a:$dstStreamId ${format.codec} -b:a ${kbRate}k '
        '-ac:a:$dstStreamId $channels -strict 2';
  }
}

abstract class VideoStreamConvert
    with EquatableMixin
    implements MapStreamSelection, Built<VideoStreamConvert, VideoStreamConvertBuilder> {
  VideoStreamConvert._();
  factory VideoStreamConvert([void Function(VideoStreamConvertBuilder) updates]) =
      _$VideoStreamConvert;

  @override
  List<Object> get props => [inputFileId, srcStreamId, dstStreamId];

  @override
  String toString() => '-map $inputFileId:v:$srcStreamId -c:v:$dstStreamId hevc -vtag hvc1';
}

abstract class StreamSelection extends StreamOption {
  int get streamId;
  TrackType get trackType;
}

abstract class StreamDisposition
    with EquatableMixin
    implements StreamSelection, Built<StreamDisposition, StreamDispositionBuilder> {
  StreamDisposition._();
  factory StreamDisposition([void Function(StreamDispositionBuilder) updates]) =
      _$StreamDisposition;

  bool get isDefault;

  @override
  List<Object> get props => [streamId, trackType, isDefault];

  @override
  String toString() {
    var disposition = isDefault ? 'default' : '0';
    return '-disposition:${trackType.abbrev}:$streamId $disposition';
  }
}

abstract class ComplexFilter
    with EquatableMixin
    implements StreamOption, Built<ComplexFilter, ComplexFilterBuilder> {
  ComplexFilter._();
  factory ComplexFilter([void Function(ComplexFilterBuilder) updates]) = _$ComplexFilter;
  factory ComplexFilter.fromFilter(String filter) => _$ComplexFilter._(filter: filter);

  String get filter;

  @override
  List<Object> get props => [filter];

  @override
  String toString() {
    return '-filter_complex "$filter"';
  }
}

abstract class GlobalMetadata
    with EquatableMixin
    implements StreamOption, Built<GlobalMetadata, GlobalMetadataBuilder> {
  GlobalMetadata._();
  factory GlobalMetadata([void Function(GlobalMetadataBuilder) updates]) = _$GlobalMetadata;

  String get name;
  String get value;

  @override
  List<Object> get props => [name, value];

  @override
  String toString() {
    return '-metadata $name="$value"';
  }
}

abstract class StreamMetadata
    with EquatableMixin
    implements StreamSelection, Built<StreamMetadata, StreamMetadataBuilder> {
  StreamMetadata._();
  factory StreamMetadata([void Function(StreamMetadataBuilder) updates]) = _$StreamMetadata;

  String get name;
  String get value;

  @override
  List<Object> get props => [streamId, trackType, name, value];

  @override
  String toString() => '-metadata:s:${trackType.abbrev}:$streamId $name="$value"';
}

abstract class StreamFilter implements StreamOption {}

abstract class ScaleFilter
    with EquatableMixin
    implements StreamFilter, Built<ScaleFilter, ScaleFilterBuilder> {
  ScaleFilter._();
  factory ScaleFilter([void Function(ScaleFilterBuilder) updates]) = _$ScaleFilter;
  factory ScaleFilter.withDefaultHeight(int width) => _$ScaleFilter._(width: width, height: -2);

  String? get algorithm;
  int get height;
  int get width;

  @override
  List<Object?> get props => [algorithm, height, width];

  @override
  String toString() {
    var filter = '-vf scale=$width:$height';
    if (algorithm != null) {
      return '$filter -sws_flags $algorithm';
    }
    return filter;
  }
}
