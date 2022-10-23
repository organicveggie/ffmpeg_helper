import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_helpers.dart';
import 'track.dart';

part 'audio_track.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class AudioTrack extends CodecIdTrack with EquatableMixin {
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: 'Format_AdditionalFeatures')
  final String? formatAdditionalFeatures;
  @JsonKey(name: 'Format_Commercial_IfAny')
  final String? formatCommercialName;
  @JsonKey(name: '@typeorder', fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int typeOrder;

  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int? channels;

  final String? channelPositions;
  final String? channelLayout;
  final String format;
  final String? language;
  final String streamOrder;

  final String? title;

  @JsonKey(name: 'Default', fromJson: jsonStringToBool)
  final bool isDefault;
  @JsonKey(name: 'Forced', fromJson: jsonStringToBool)
  final bool isForced;

  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int? bitRate;
  @JsonKey(name: 'BitRate_Mode', fromJson: jsonStringToBitRateMode, toJson: jsonBitRateModeToString)
  final BitRateMode? bitRateMode;
  @JsonKey(name: 'BitRate_Maximum', fromJson: jsonStringToInt, toJson: jsonIntToString)
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

  const AudioTrack.fromParams({
    required String id,
    required String codecId,
    required String format,
    required String streamOrder,
    required int typeOrder,
    int? bitRate,
    int? bitRateMax,
    BitRateMode? bitRateMode,
    int? channels,
    String? channelLayout,
    String? channelPositions,
    String? compressionMode,
    Map<String, String>? extra,
    String? formatAdditionalFeatures,
    String? formatCommercialName,
    bool isDefault = false,
    bool isForced = false,
    String? language,
    String? title,
    String? uniqueId,
  }) : this(
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

  factory AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);

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
  int? get bitRateLimit {
    if (bitRateMode == BitRateMode.variable) {
      return null;
    }
    return bitRate ?? bitRateMax;
  }

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

abstract class AudioTrackWrapper implements Built<AudioTrackWrapper, AudioTrackWrapperBuilder> {
  AudioFormat get format;
  AudioTrack get track;
  int get orderId;

  AudioTrackWrapper._();
  factory AudioTrackWrapper(int orderId, AudioTrack track) {
    return _$AudioTrackWrapper._(format: track.toAudioFormat(), track: track, orderId: orderId);
  }
}
