// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../models/wrappers.dart' as wrappers;

import '../cli/audio_finder.dart';
import '../cli/conversions.dart';
import 'exceptions.dart';

part 'suggest.g.dart';

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

/// Convert supported 2 or 3 character language abbreviations into ISO639-2.
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

List<StreamOption> processAudioTracks(SuggestOptions opts, BuiltList<AudioTrack> tracks) {
  final log = Logger('processAudioTracks');

  // Organize audio tracks by format and filter out any commentary tracks.
  Map<AudioFormat, wrappers.AudioTrack> tracksByFormat = {};
  for (int i = 0; i < tracks.length; i++) {
    AudioTrack t = tracks[i];
    if (t.title != null && t.title!.toLowerCase().contains('commentary')) {
      continue;
    }
    var af = t.toAudioFormat();
    tracksByFormat[af] = wrappers.AudioTrack(i, t);
  }

  var streamOpts = <StreamOption>[];

  // Find the best audio source track for the main multichannel audio track.
  var audioFinder = AudioFinder((af) => af..tracksByFormat.addAll(tracksByFormat));
  var source = audioFinder.bestForEAC3();

  if (source.format == AudioFormat.mono || source.format == AudioFormat.stereo) {
    // No multichannel audio tracks available, so skip dealing with multichannel audio entirely
    // and include only this track.
    log.fine('Only available source is ${source.format.name}.');
    streamOpts.addAll([
      (StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 0)
          .build(),
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = 0
            ..isDefault = true)
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = 0
            ..name = 'title'
            ..value = 'AAC (${source.format.name})')
          .build(),
    ]);
  } else {
    // Multichannel audio tracks.
    // First track should be Dolby Digital Plus or Dolby Digital, if possible.
    // Prefer using a Dolby Digital Plus or Dolby Digital track as the source for the first track.
    AudioFormat firstTrackFormat = AudioFormat.unknown;
    if (source.format == AudioFormat.dolbyDigitalPlus ||
        source.format == AudioFormat.dolbyDigital) {
      firstTrackFormat = source.format;
      log.fine('Copying ${source.format.name} (track #${source.orderId}) to track #0.');
      streamOpts.add((StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 0)
          .build());
    } else {
      // Source track is not Dolby Digital Plus or Dolby Digital, so transcode.
      firstTrackFormat = AudioFormat.dolbyDigitalPlus;
      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 0
            ..format = AudioFormat.dolbyDigitalPlus
            ..channels = source.track.channels
            ..kbRate = maxAudioKbRate(source.track, 384))
          .build());
    }
    streamOpts.addAll([
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = 0
            ..isDefault = true)
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = 0
            ..name = 'title'
            ..value = firstTrackFormat.name)
          .build(),
    ]);

    // Find the best audio source track for the multichannel AAC track.
    source = audioFinder.bestForMultiChannelAAC();
    if (source.format == AudioFormat.aacMulti) {
      log.fine('Copying ${source.format.name} (track #${source.orderId}) to track #1.');
      streamOpts.add((StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 1)
          .build());
    } else {
      int kbRate = maxAudioKbRate(source.track, 384);
      int channels = (source.track.channels != null && source.track.channels! < 6)
          ? source.track.channels!
          : 6;
      log.fine('Transcoding ${source.format.name} (track #${source.orderId}) '
          'to AAC ($channels channels) $kbRate kbps as track #1.');
      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 1
            ..format = AudioFormat.aacMulti
            ..channels = channels
            ..kbRate = kbRate)
          .build());
    }
    streamOpts.addAll([
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = 1
            ..isDefault = false)
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = 1
            ..name = 'title'
            ..value = 'AAC (5.1)')
          .build(),
    ]);

    // Dolby Pro Logic II
    if (opts.generateDPL2) {
      streamOpts.add(ComplexFilter.fromFilter('[0:a]aresample=matrix_encoding=dplii[a]'));
      // Find the best audio source track for the Dolby Pro Logic II AAC track.
      source = audioFinder.bestForDolbyProLogic2();
      int kbRate = maxAudioKbRate(source.track, 256);
      log.fine('Transcoding ${source.format.name} (track #${source.orderId}) to '
          'AAC (Dolby Pro Logic II) $kbRate kbps as track #2.');
      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 2
            ..format = AudioFormat.stereo
            ..channels = 2
            ..kbRate = kbRate)
          .build());
      streamOpts.addAll([
        (StreamDispositionBuilder()
              ..trackType = TrackType.audio
              ..streamId = 2
              ..isDefault = false)
            .build(),
        (StreamMetadataBuilder()
              ..trackType = TrackType.audio
              ..streamId = 2
              ..name = 'title'
              ..value = 'AAC (Dolby Pro Logic II)')
            .build(),
      ]);
    }
  }

  return streamOpts;
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

int maxAudioKbRate(AudioTrack track, int defaultMaxKbRate) {
  if (track.bitRateLimit != null) {
    int kbRateLimit = track.bitRateLimit! ~/ 1024;
    return (kbRateLimit < defaultMaxKbRate) ? kbRateLimit : defaultMaxKbRate;
  }

  return defaultMaxKbRate;
}
