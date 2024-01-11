import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_helpers.dart';
import 'track.dart';

part 'video_track.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class VideoTrack extends CodecIdTrack with EquatableMixin {
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'HDR_Format')
  final String? hdrFormat;
  @JsonKey(name: 'HDR_Format_Compatibility')
  final String? hdrFormatCompatibility;

  final String format;

  final String? streamOrder;

  @JsonKey(name: '@typeorder')
  final String? typeOrder;

  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int height;
  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
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
      this.hdrFormatCompatibility,
      this.typeOrder);

  const VideoTrack.createFromParams({
    required String codecId,
    required String format,
    required int height,
    required String id,
    String? streamOrder,
    required int width,
    Map<String, String>? extra,
    String? hdrFormat,
    String? hdrFormatCompatibility,
    String? uniqueId,
    String? typeOrder,
  }) : this(TrackType.video, id, codecId, uniqueId, streamOrder, extra, format, width, height,
            hdrFormat, hdrFormatCompatibility, typeOrder);

  factory VideoTrack.fromJson(Map<String, dynamic> json) => _$VideoTrackFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$VideoTrackToJson(this);

  bool get isHDR => hdrFormat != null;
  String get hdrName => isHDR ? 'HDR' : 'SDR';

  String get sizeName {
    if (width == 1920 || height <= 1080) {
      return '1080p';
    } else if (width == 3840 || height <= 2160) {
      return '2160p';
    }
    return 'unknown';
  }

  VideoResolution? get videoResolution {
    if (width == 1920 || height <= 1080) {
      return VideoResolution.hd;
    } else if (width == 3840 || height <= 2160) {
      return VideoResolution.uhd;
    }
    return null;
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
        hdrFormatCompatibility,
        typeOrder
      ];
}
