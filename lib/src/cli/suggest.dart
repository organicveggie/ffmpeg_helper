// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../cli/audio_finder.dart';
import '../cli/conversions.dart';
import 'exceptions.dart';

part 'suggest.g.dart';

////////////////////
// Data Models
////////////////////

abstract class MovieTitle with EquatableMixin implements Built<MovieTitle, MovieTitleBuilder> {
  MovieTitle._();
  factory MovieTitle([void Function(MovieTitleBuilder) updates]) = _$MovieTitle;

  String get name;
  String? get year;

  @override
  List<Object?> get props => [name, year];

  @override
  String toString() {
    return (year == null) ? name : '$name ($year)';
  }
}

abstract class SuggestOptions
    with EquatableMixin
    implements Built<SuggestOptions, SuggestOptionsBuilder> {
  bool get forceUpscaling;
  bool get generateDPL2;
  bool get movieOutputLetterPrefix;
  bool get overwriteOutputFile;

  MediaType get mediaType;
  String? get outputFile;
  String? get outputFolder;
  VideoResolution? get targetResolution;

  SuggestOptions._();
  factory SuggestOptions([void Function(SuggestOptionsBuilder) updates]) = _$SuggestOptions;

  factory SuggestOptions.withDefaults(
      {required bool force,
      required bool dpl2,
      required MediaType mediaType,
      bool? movieOutputLetterPrefix,
      String? outputFile,
      String? outputFolder,
      bool? overwriteOutputFile,
      VideoResolution? targetResolution}) {
    return (SuggestOptionsBuilder()
          ..forceUpscaling = force
          ..generateDPL2 = dpl2
          ..mediaType = mediaType
          ..movieOutputLetterPrefix = movieOutputLetterPrefix ?? false
          ..outputFile = outputFile
          ..outputFolder = outputFolder
          ..overwriteOutputFile = overwriteOutputFile ?? false
          ..targetResolution = targetResolution)
        .build();
  }

  @override
  List<Object?> get props => [
        forceUpscaling,
        generateDPL2,
        movieOutputLetterPrefix,
        overwriteOutputFile,
        mediaType,
        outputFile,
        outputFolder,
        targetResolution
      ];
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

BuiltList<String> processFile(SuggestOptions opts, String filename, TrackList tracks) {
  var streamOptions = <StreamOption>[];

  // Check video track
  var video = tracks.videoTracks.first;
  var videoStreamOpts = processVideoTrack(opts, video);
  streamOptions.addAll(videoStreamOpts);

  // Check subtitles
  var subtitleStreamOpts = processSubtitles(tracks.textTracks.build());
  streamOptions.addAll(subtitleStreamOpts);

  // Check audio tracks
  var audioStreamOpts = processAudioTracks(opts, tracks.audioTracks.build());
  streamOptions.addAll(audioStreamOpts);

  var buffer = <String>[];
  buffer.add('ffmpeg -i $filename \\');

  var movieTitle = extractMovieTitle(filename);
  streamOptions.add((GlobalMetadataBuilder()
        ..name = 'title'
        ..value = movieTitle.name)
      .build());

  String outputFilename = makeOutputName(
      isHdr: video.isHDR,
      letterPrefix: opts.movieOutputLetterPrefix,
      movieTitle: movieTitle,
      outputFolder: opts.outputFolder,
      targetResolution: opts.targetResolution ?? video.videoResolution);

  for (var opt in streamOptions) {
    buffer.add(' ${opt.toString()} \\');
  }
  buffer.add(outputFilename);

  return buffer.build();
}

List<StreamOption> processAudioTracks(SuggestOptions opts, BuiltList<AudioTrack> tracks) {
  final log = Logger('processAudioTracks');

  log.info('Analyzing ${tracks.length} audio tracks.');

  // Organize audio tracks by format and filter out any commentary tracks.
  Map<AudioFormat, AudioTrackWrapper> tracksByFormat = {};
  for (int i = 0; i < tracks.length; i++) {
    AudioTrack t = tracks[i];
    if (t.title != null && t.title!.toLowerCase().contains('commentary')) {
      continue;
    }
    var af = t.toAudioFormat();
    tracksByFormat[af] = AudioTrackWrapper(i, t);
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
      // Note: ffmpeg EAC3 encoder can't handle > 5.1 channels.
      if (source.track.channels != null && source.track.channels! > 6) {
        // Force transcoding to 5.1
        log.info('Source track is ${source.format} with ${source.track.channels}, but ffmpeg only '
            'supports 5.1. Transcoding to 5.1.');
        firstTrackFormat = AudioFormat.dolbyDigitalPlus;
        streamOpts.add((AudioStreamConvertBuilder()
              ..inputFileId = 0
              ..srcStreamId = source.orderId
              ..dstStreamId = 0
              ..format = AudioFormat.dolbyDigitalPlus
              ..channels = 6
              ..kbRate = maxAudioKbRate(source.track, 384))
            .build());
      } else {
        // Already 5.1 or lower.
        firstTrackFormat = source.format;
        log.fine('Copying ${source.format.name} (track #${source.orderId}) to track #0.');
        streamOpts.add((StreamCopyBuilder()
              ..trackType = TrackType.audio
              ..inputFileId = 0
              ..srcStreamId = source.orderId
              ..dstStreamId = 0)
            .build());
      }
    } else {
      // Source track is not Dolby Digital Plus or Dolby Digital, so transcode.
      firstTrackFormat = AudioFormat.dolbyDigitalPlus;

      // Note: ffmpeg EAC3 encoder can't handle > 5.1 channels.
      var channels = source.track.channels;
      if (source.track.channels != null && source.track.channels! > 6) {
        channels = 6;
      }

      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = source.orderId
            ..dstStreamId = 0
            ..format = AudioFormat.dolbyDigitalPlus
            ..channels = channels
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
      streamOpts.add((DolbyProLogicAudioStreamConvertBuilder()
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

  log.info('Analyzing ${subtitles.length} subtitle tracks.');
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
    log.info('Video already encoded with H.265.');
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

extension CapitalExtension on String {
  String get capitalizeFirstLetter {
    if (length == 0) return '';
    if (length == 1) return this[0].toUpperCase();
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get capitalizeEveryWord {
    return split(' ')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.capitalizeFirstLetter)
        .join(' ');
  }
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

  name = name.capitalizeEveryWord;
  return (MovieTitleBuilder()
        ..name = name
        ..year = year)
      .build();
}

final _movieTitleStopWords = BuiltSet<String>(['a', 'an', 'the']);
final _movieNumberRegex = RegExp(r'[0-9]');

String getMovieTitleFirstLetter(String title) {
  var titleWords = title.toLowerCase().split(' ');
  var firstLetter = titleWords[0][0];

  for (var w in titleWords) {
    if (_movieTitleStopWords.contains(w)) {
      continue;
    }
    firstLetter = w.substring(0, 1);
    break;
  }

  if (_movieNumberRegex.matchAsPrefix(firstLetter) != null) {
    firstLetter = '0-9';
  }

  return firstLetter.toUpperCase();
}

String makeOutputName(
    {required MovieTitle movieTitle,
    bool isHdr = false,
    bool letterPrefix = false,
    String? outputFolder,
    VideoResolution? targetResolution}) {
  final baseNameBuffer = StringBuffer(movieTitle.name);
  if (movieTitle.year != null) {
    baseNameBuffer.write(' (${movieTitle.year})');
  }

  final fileNameBuffer = StringBuffer(baseNameBuffer);
  if (targetResolution != null) {
    fileNameBuffer.write(' - ${targetResolution.toSizeName()}');
  }
  if (isHdr) {
    fileNameBuffer.write('-HDR');
  }
  fileNameBuffer.write('.mkv');

  var firstLetter = '';
  if (letterPrefix) {
    firstLetter = getMovieTitleFirstLetter(movieTitle.name);
  }
  return p.join(outputFolder ?? '', firstLetter, '"${baseNameBuffer.toString()}"',
      '"${fileNameBuffer.toString()}"');
}

String makeTvOutputName(
    {required TvEpisode episode,
    bool isHdr = false,
    String? outputFolder,
    VideoResolution? targetResolution}) {
  StringBuffer buffer = StringBuffer(episode.asFullName());

  if ((targetResolution == VideoResolution.uhd || isHdr)) {
    buffer.write(' - [');
    if (targetResolution == VideoResolution.uhd) {
      buffer.write(targetResolution!.toSizeName());
      if (isHdr) {
        buffer.write(' ');
      }
    }
    if (isHdr) {
      buffer.write('HDR');
    }
    buffer.write(']');
  }
  buffer.write('.mkv');

  var season = 'season${episode.season}';

  return p.join('"${episode.series.asFullName()}"', season, '"${buffer.toString()}"');
}

int maxAudioKbRate(AudioTrack track, int defaultMaxKbRate) {
  if (track.bitRateMode == BitRateMode.variable) {
    return defaultMaxKbRate;
  }

  if (track.bitRateLimit != null) {
    int kbRateLimit = track.bitRateLimit! ~/ 1024;
    return (kbRateLimit < defaultMaxKbRate) ? kbRateLimit : defaultMaxKbRate;
  }

  return defaultMaxKbRate;
}
