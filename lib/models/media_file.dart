import 'dart:math';

import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';

part 'media_file.g.dart';

abstract class MediaFile with EquatableMixin implements Built<MediaFile, MediaFileBuilder> {
  String get filename;
  String get path;
  int? get sizeInBytes;

  String? getFileSizeAsString({int decimals = 0}) {
    if (sizeInBytes == null) {
      return null;
    }
    var bytes = sizeInBytes!;
    const suffixes = ['b', 'kb', 'mb', 'gb', 'tb'];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
  }

  MediaFile._();
  factory MediaFile([void Function(MediaFileBuilder) updates]) = _$MediaFile;

  @override
  List<Object?> get props => [filename, path, sizeInBytes];

  @override
  bool get stringify => true;
}
