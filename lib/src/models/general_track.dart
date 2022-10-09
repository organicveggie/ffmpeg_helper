import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_helpers.dart';
import 'track.dart';

part 'general_track.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class GeneralTrack extends Track with EquatableMixin {
  @JsonKey(name: "UniqueID")
  final String? uniqueId;
  final String fileExtension;
  final String? format;
  final String? movie;
  final String? title;

  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int? audioCount;
  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int? menuCount;
  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int? textCount;
  @JsonKey(fromJson: jsonStringToInt, toJson: jsonIntToString)
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
