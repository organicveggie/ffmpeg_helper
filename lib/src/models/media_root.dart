import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'media.dart';

part 'media_root.g.dart';

@JsonSerializable()
class MediaRoot with EquatableMixin {
  const MediaRoot(this.media);

  final Media media;

  factory MediaRoot.fromJson(Map<String, dynamic> json) => _$MediaRootFromJson(json);

  Map<String, dynamic> toJson() => _$MediaRootToJson(this);

  @override
  List<Object?> get props => [media];
}
