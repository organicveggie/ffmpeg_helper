import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'track.g.dart';

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
