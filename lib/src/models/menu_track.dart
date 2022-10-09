import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'track.dart';

part 'menu_track.g.dart';

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
