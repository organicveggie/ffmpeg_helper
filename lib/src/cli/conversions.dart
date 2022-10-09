import 'package:built_value/built_value.dart';
import 'package:ffmpeg_helper/models.dart';

part 'conversions.g.dart';

enum ConversionOp {
  copy,
  transcode;
}

abstract class AudioConversion implements Built<AudioConversion, AudioConversionBuilder> {
  int get srcStreamId;
  int get dstStreamId;

  AudioFormat get format;
  ConversionOp get op;

  bool get isDolbyProLogic2;

  // Common details
  bool get isDefault;
  String? get subtitle;

  // Transcoding details
  int? get kbRate;
  int? get numChannels;

  @override
  String toString() {
    var output = <String>[];

    if (isDolbyProLogic2) {
      output.add('-filter_complex "[0:a]aresample=matrix_encoding=dplii[a]"');
    }

    if (op == ConversionOp.copy) {
      output.add('-map 0:a:$srcStreamId -c:a:$dstStreamId copy');
    } else {}

    var disposition = isDefault ? 'default' : '0';
    output.add('-disposition:a:$dstStreamId $disposition');

    var streamTitle = (subtitle == null) ? format.name : '${format.name} ($subtitle)';
    output.add('-metadata:s:a:$dstStreamId title="$streamTitle"');

    return output.join(' \\\n');
  }

  AudioConversion._();
  factory AudioConversion([void Function(AudioConversionBuilder) updates]) = _$AudioConversion;
}

abstract class StreamOption {
  @override
  String toString();
}

abstract class MapStreamSelection extends StreamOption {
  int get srcStreamId;
  int get dstStreamId;

  int get inputFileId;
}

abstract class StreamCopy implements MapStreamSelection, Built<StreamCopy, StreamCopyBuilder> {
  StreamCopy._();
  factory StreamCopy([void Function(StreamCopyBuilder) updates]) = _$StreamCopy;

  TrackType get trackType;

  @override
  String toString() {
    var ttAbbrev = _trackTypeAbbrev(trackType);
    return '-map $inputFileId:$ttAbbrev:$srcStreamId -c:$ttAbbrev:$dstStreamId copy';
  }
}

abstract class AudioStreamConvert
    implements MapStreamSelection, Built<AudioStreamConvert, AudioStreamConvertBuilder> {
  AudioStreamConvert._();
  factory AudioStreamConvert([void Function(AudioStreamConvertBuilder) updates]) =
      _$AudioStreamConvert;

  int get channels;
  AudioFormat get format;
  int get kbRate;

  @override
  String toString() {
    var codec = '';
    switch (format) {
      case AudioFormat.dolbyDigitalPlus:
        codec = 'eac3';
        break;
      case AudioFormat.dolbyDigital:
        codec = 'ac3';
        break;
      case AudioFormat.dtsX:
        codec = 'dts';
        break;
      case AudioFormat.dts:
        codec = 'dts';
        break;
      case AudioFormat.aacMulti:
        codec = 'aac';
        break;
      case AudioFormat.stereo:
        codec = 'aac';
        break;
      case AudioFormat.mono:
        codec = 'aac';
        break;
      default:
        codec = 'unknown';
        break;
    }

    return '-map $inputFileId:a:$srcStreamId -c:a:$dstStreamId $codec -b:a ${kbRate}k -ac:a:$dstStreamId $channels';
  }
}

abstract class VideoStreamConvert
    implements MapStreamSelection, Built<VideoStreamConvert, VideoStreamConvertBuilder> {
  VideoStreamConvert._();
  factory VideoStreamConvert([void Function(VideoStreamConvertBuilder) updates]) =
      _$VideoStreamConvert;

  @override
  String toString() {
    return '-map $inputFileId:v:$srcStreamId -c:v:$dstStreamId hevc -vtag hvc1';
  }
}

abstract class StreamSelection extends StreamOption {
  int get streamId;
  TrackType get trackType;
}

abstract class StreamDisposition
    implements StreamSelection, Built<StreamDisposition, StreamDispositionBuilder> {
  StreamDisposition._();
  factory StreamDisposition([void Function(StreamDispositionBuilder) updates]) =
      _$StreamDisposition;

  bool get isDefault;

  @override
  String toString() {
    var ttAbbrev = _trackTypeAbbrev(trackType);
    var disposition = isDefault ? 'default' : '0';

    return '-disposition:$ttAbbrev:$streamId $disposition';
  }
}

abstract class ComplexFilter implements StreamOption, Built<ComplexFilter, ComplexFilterBuilder> {
  ComplexFilter._();
  factory ComplexFilter([void Function(ComplexFilterBuilder) updates]) = _$ComplexFilter;

  String get filter;

  @override
  String toString() {
    return 'filter_complex "$filter"';
  }
}

abstract class GlobalMetadata
    implements StreamOption, Built<GlobalMetadata, GlobalMetadataBuilder> {
  GlobalMetadata._();
  factory GlobalMetadata([void Function(GlobalMetadataBuilder) updates]) = _$GlobalMetadata;

  String get name;
  String get value;

  @override
  String toString() {
    return '-metadata $name="$value"';
  }
}

abstract class StreamMetadata
    implements StreamSelection, Built<StreamMetadata, StreamMetadataBuilder> {
  StreamMetadata._();
  factory StreamMetadata([void Function(StreamMetadataBuilder) updates]) = _$StreamMetadata;

  String get name;
  String get value;

  @override
  String toString() {
    var ttAbbrev = _trackTypeAbbrev(trackType);
    return '-metadata:s:$ttAbbrev:$streamId $name="$value"';
  }
}

abstract class StreamFilter implements StreamOption {}

abstract class ScaleFilter implements StreamFilter, Built<ScaleFilter, ScaleFilterBuilder> {
  ScaleFilter._();
  factory ScaleFilter([void Function(ScaleFilterBuilder) updates]) = _$ScaleFilter;

  String? get algorithm;
  int get height;
  int get width;

  @override
  String toString() {
    var filter = '-vf scale=$width:$height';
    if (algorithm != null) {
      return '$filter -sws_flags $algorithm';
    }
    return filter;
  }
}

String _trackTypeAbbrev(TrackType tt) {
  switch (tt) {
    case TrackType.audio:
      return 'a';
    case TrackType.general:
      return 'g';
    case TrackType.menu:
      return 'm';
    case TrackType.text:
      return 's';
    case TrackType.video:
      return 'v';
    default:
      break;
  }
  // TODO: Throw exception
  return 'UNKNOWN';
}
