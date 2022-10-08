import 'package:built_value/built_value.dart';

import 'exceptions.dart';

part 'suggest.g.dart';

enum MediaType {
  movie,
  tv;

  static Iterable<String> names() => MediaType.values.map((v) => v.name);
}

extension MediaTypeParsing on String {
  MediaType parseMediaType() {
    var lower = toLowerCase();
    for (var mt in MediaType.values) {
      if (lower == mt.name) {
        return mt;
      }
    }
    throw ArgParsingFailedException('MediaType', this);
  }
}

enum VideoResolution {
  hd(['1080', '1080p']),
  uhd(['4k', '2160', '2160p']);

  final List<String> aliases;

  const VideoResolution(this.aliases);

  static Iterable<String> names() => VideoResolution.values.map((v) => v.name);
  static Iterable<String> allNames() {
    var all = <String>[];
    for (var v in VideoResolution.values) {
      all.add(v.name);
      all.addAll(v.aliases);
    }
    all.sort();
    return all;
  }
}

extension VideoResolutionParsing on String {
  VideoResolution parseVideoResolution() {
    var lower = toLowerCase();
    for (var v in VideoResolution.values) {
      if ((lower == v.name) || (v.aliases.contains(lower))) {
        return v;
      }
    }
    throw ArgParsingFailedException('VideoResolution', this);
  }
}

abstract class SuggestOptions implements Built<SuggestOptions, SuggestOptionsBuilder> {
  bool get forceUpscaling;
  bool get generateDPL2;
  MediaType get mediaType;
  String? get outputFolder;
  VideoResolution? get targetResolution;

  SuggestOptions._();
  factory SuggestOptions([void Function(SuggestOptionsBuilder) updates]) = _$SuggestOptions;

  factory SuggestOptions.fromStrings(
      {required bool force,
      required bool dpl2,
      required String mediaType,
      String? outputFolder,
      String? targetResolution}) {
    return SuggestOptions((o) => o
      ..forceUpscaling = force
      ..generateDPL2 = dpl2
      ..mediaType = mediaType.parseMediaType()
      ..outputFolder = outputFolder
      ..targetResolution = targetResolution?.parseVideoResolution());
  }
}
