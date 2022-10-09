import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'exceptions.dart';

part 'suggest.g.dart';

////////////////////
// Enums
////////////////////

enum MediaType {
  movie,
  tv;

  static Iterable<String> names() => MediaType.values.map((v) => v.name);
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

////////////////////
/// Extensions
////////////////////

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

////////////////////
// Data Models
////////////////////

abstract class MovieTitle implements Built<MovieTitle, MovieTitleBuilder> {
  MovieTitle._();
  factory MovieTitle([void Function(MovieTitleBuilder) updates]) = _$MovieTitle;

  String get name;
  String? get year;

  @override
  String toString() {
    return (year == null) ? name : '$name ($year)';
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

////////////////////
// Functions
////////////////////
///
String langToISO639_2(String lang) {
  switch (lang) {
    case 'de':
    case 'deu':
      return 'deu';
    case 'en':
    case 'eng':
      return 'eng';
    case 'es':
    case 'esp':
      return 'esp';
    case 'fr':
    case 'fra':
      return 'fra';
    default:
      return lang;
  }
}

String processFileExperimentalMode(SuggestOptions opts, String filename, TrackList tracks) {
  var streamOptions = <StreamOption>[];

  // Check video track
  var video = tracks.videoTracks.first;
  var videoStreamOpts = processVideoTrack(opts, video);
  streamOptions.addAll(videoStreamOpts);

  // Check subtitles
  var subtitleStreamOpts = processSubtitles(tracks.textTracks.build());
  streamOptions.addAll(subtitleStreamOpts);

  StringBuffer buffer = StringBuffer();
  buffer.writeln('ffmpeg -i $filename \\');

  var movieTitle = extractMovieTitle(filename);
  String outputFilename = makeOutputName(movieTitle, video);

  for (var opt in streamOptions) {
    buffer.write(opt.toString());
    buffer.writeln(' \\');
  }
  buffer.writeln(outputFilename);

  return buffer.toString();
}

List<StreamOption> processSubtitles(BuiltList<TextTrack> subtitles) {
  final log = Logger('processSubtitles');

  var streamOpts = <StreamOption>[];

  log.info('Analyzing ${subtitles.length} subtitle tracks...');
  var subLangs = Set.unmodifiable(['en', 'eng', 'es', 'esp', 'fr', 'fra', 'de', 'deu']);
  var destStreamId = 0;
  for (int i = 0; i < subtitles.length; i++) {
    TextTrack tt = subtitles[i];
    if (!subLangs.contains(tt.language)) {
      continue;
    }
    streamOpts.add((StreamCopyBuilder()
          ..trackType = TrackType.text
          ..inputFileId = 0
          ..srcStreamId = i
          ..dstStreamId = destStreamId)
        .build());

    streamOpts.add((StreamMetadataBuilder()
          ..trackType = TrackType.text
          ..streamId = destStreamId
          ..name = 'language'
          ..value = langToISO639_2(tt.language))
        .build());

    streamOpts.add((StreamMetadataBuilder()
          ..trackType = TrackType.text
          ..streamId = destStreamId
          ..name = 'handler'
          ..value = tt.handler)
        .build());

    destStreamId++;
  }

  return streamOpts;
}

List<StreamOption> processVideoTrack(SuggestOptions opts, VideoTrack video) {
  final log = Logger('processVideoTrack');
  var streamOpts = <StreamOption>[];

  // Check if we need to apply a scaling filter.
  if (opts.targetResolution == VideoResolution.uhd && video.width < 3840) {
    if (!opts.forceUpscaling) {
      throw UpscalingRequiredException(opts.targetResolution!, video.width);
    }
    log.info('Upscaling from width of ${video.width} to ${opts.targetResolution!.name}.');
    streamOpts.add((ScaleFilterBuilder()
          ..width = 3840
          ..height = -1)
        .build());
    // Convert to H.265
    streamOpts.add((VideoStreamConvertBuilder()
          ..inputFileId = 0
          ..srcStreamId = 0
          ..dstStreamId = 0)
        .build());
  } else if (opts.targetResolution == VideoResolution.hd && video.width > 1920) {
    log.info('Downscaling from width of ${video.width} to ${opts.targetResolution!.name}.');
    streamOpts.add((ScaleFilterBuilder()
          ..width = 1920
          ..height = -1)
        .build());
    // Convert to H.265
    streamOpts.add((VideoStreamConvertBuilder()
          ..inputFileId = 0
          ..srcStreamId = 0
          ..dstStreamId = 0)
        .build());
  } else if (video.format == 'HEVC') {
    log.info('Video already encoded with H.265. Copying to destination.');
    streamOpts.add((StreamCopyBuilder()
          ..inputFileId = 0
          ..srcStreamId = 0
          ..dstStreamId = 0
          ..trackType = TrackType.video)
        .build());
  } else {
    // Convert to H.265
    log.info('Converting video to H.265.');
    streamOpts.add((VideoStreamConvertBuilder()
          ..inputFileId = 0
          ..srcStreamId = 0
          ..dstStreamId = 0)
        .build());
  }

  return streamOpts;
}

MovieTitle extractMovieTitle(String sourcePathname) {
  final sourceFilename = p.basename(sourcePathname);

  var name = 'unknown';
  String? year;

  // Try to identify the name and year of the movie.
  var regex = RegExp(r'^(?<name>(\w+[.]?)+?)[.]?(?<year>(19\d\d|20\d\d))?[.].*[.](mkv|mp4|m4v)$');
  var match = regex.firstMatch(sourceFilename);
  if (match != null) {
    final rawName = match.namedGroup('name');
    if (rawName != null) {
      name = rawName.replaceAll('.', ' ').trim();
      year = match.namedGroup('year');
    }
  }

  return (MovieTitleBuilder()
        ..name = name
        ..year = year)
      .build();
}

String makeOutputName(MovieTitle movieTitle, VideoTrack video) {
  final baseNameBuffer = StringBuffer(movieTitle.name);
  if (movieTitle.year != null) {
    baseNameBuffer.write(' (${movieTitle.year})');
  }

  final fileNameBuffer = StringBuffer(baseNameBuffer);
  if (video.sizeName != "unknown") {
    fileNameBuffer.write(' - ${video.sizeName}');
  }
  if (video.isHDR) {
    fileNameBuffer.write(' - HDR');
  }

  fileNameBuffer.write('.mkv');

  return p.join(baseNameBuffer.toString(), fileNameBuffer.toString());
}
