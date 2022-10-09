import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'track_list.dart';

part 'media.g.dart';

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
