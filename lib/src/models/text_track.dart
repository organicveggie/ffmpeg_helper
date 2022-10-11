import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_helpers.dart';
import 'track.dart';

part 'text_track.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class TextTrack extends Track with EquatableMixin {
  @JsonKey(name: 'CodecID')
  final String? codecId;
  @JsonKey(name: 'extra')
  final Map<String, String>? extra;
  @JsonKey(name: '@typeorder', fromJson: jsonStringToInt, toJson: jsonIntToString)
  final int typeOrder;
  @JsonKey(name: 'ID')
  final String id;
  @JsonKey(name: 'UniqueID')
  final String? uniqueId;

  final String? format;
  final String language;
  final String? title;

  @JsonKey(name: 'Default', fromJson: jsonStringToBool)
  final bool isDefault;
  @JsonKey(name: 'Forced', fromJson: jsonStringToBool)
  final bool isForced;

  const TextTrack(super.type, this.typeOrder, this.id, this.uniqueId, this.extra, this.title,
      this.language, this.isDefault, this.isForced, this.format, this.codecId);

  factory TextTrack.fromJson(Map<String, dynamic> json) => _$TextTrackFromJson(json);

  factory TextTrack.fromMinimum(
      int typeOrder, String id, String language, bool isDefault, bool isForced) {
    return TextTrack(
        TrackType.text, typeOrder, id, null, null, null, language, isDefault, isForced, null, null);
  }

  @override
  Map<String, dynamic> toJson() => _$TextTrackToJson(this);

  @override
  List<Object?> get props =>
      [codecId, typeOrder, id, uniqueId, extra, format, language, title, isDefault, isForced];

  String get languageName {
    switch (language) {
      case 'de':
      case 'deu':
        return 'German';
      case 'en':
      case 'eng':
        return 'English';
      case 'es':
      case 'esp':
        return 'Spanish';
      case 'fr':
      case 'fra':
        return 'French';
      default:
        return 'Unknown';
    }
  }

  String get handler {
    var buffer = StringBuffer();
    if (title == null) {
      buffer.write(languageName);
    } else if (title!.contains(languageName)) {
      buffer.write(title);
    } else {
      buffer.write(languageName);
      buffer.write(' $title');
    }
    if ((format != null && format!.startsWith('UTF')) ||
        (codecId != null && codecId!.startsWith('S_TEXT'))) {
      buffer.write(' (SRT)');
    }
    return buffer.toString();
  }

  @override
  String toString() => 'Text: $handler';
}
