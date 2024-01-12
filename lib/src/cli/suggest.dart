// ignore: depend_on_referenced_packages
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:ffmpeg_helper/mediainfo_runner.dart';
import 'package:ffmpeg_helper/models.dart';

import '../cli/audio_finder.dart';
import '../cli/conversions.dart';
import 'exceptions.dart';

part 'suggest.g.dart';

////////////////////
// Constants
////////////////////

const audioTitleAacMulti = 'AAC (5.1)';
const audioTitleDPL = 'AAC (Dolby Pro Logic II)';

////////////////////
// Data Models
////////////////////

abstract class SuggestOptions
    with EquatableMixin
    implements Built<SuggestOptions, SuggestOptionsBuilder> {
  bool get forceUpscaling;
  bool get generateDPL2;
  bool get movieOutputLetterPrefix;

  OutputFileMode get outputFileMode;

  MediaType get mediaType;
  String? get name;
  String? get outputFile;
  String? get outputFolder;
  VideoResolution? get targetResolution;
  String? get year;

  String? get imdbId;
  String? get tmdbId;
  String? get tvdbId;

  bool get preferLossless;
  Language? get language;

  String? get blurayPlaylist;
  bool isBluray() => blurayPlaylist != null;

  SuggestOptions._();
  factory SuggestOptions([void Function(SuggestOptionsBuilder) updates]) = _$SuggestOptions;

  factory SuggestOptions.withDefaults(
      {required bool force,
      required bool dpl2,
      required MediaType mediaType,
      bool? movieOutputLetterPrefix,
      String? name,
      String? outputFile,
      OutputFileMode? outputFileMode,
      String? outputFolder,
      bool preferLossless = true,
      VideoResolution? targetResolution,
      String? imdbId,
      String? tmdbId,
      String? tvdbId,
      String? year,
      Language? language,
      String? blurayPlaylist}) {
    return (SuggestOptionsBuilder()
          ..blurayPlaylist = blurayPlaylist
          ..forceUpscaling = force
          ..generateDPL2 = dpl2
          ..imdbId = imdbId
          ..language = language
          ..mediaType = mediaType
          ..movieOutputLetterPrefix = movieOutputLetterPrefix ?? false
          ..name = name
          ..outputFile = outputFile
          ..outputFileMode = outputFileMode ?? OutputFileMode.fail
          ..outputFolder = outputFolder
          ..preferLossless = preferLossless
          ..targetResolution = targetResolution
          ..tmdbId = tmdbId
          ..tvdbId = tvdbId
          ..year = year)
        .build();
  }

  @override
  List<Object?> get props => [
        blurayPlaylist,
        forceUpscaling,
        generateDPL2,
        imdbId,
        language,
        mediaType,
        movieOutputLetterPrefix,
        name,
        outputFile,
        outputFileMode,
        outputFolder,
        targetResolution,
        tmdbId,
        tvdbId,
        year
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
  final streamOptions = <StreamOption>[];

  // Check video track
  final video = tracks.videoTracks.first;
  final videoStreamOpts = processVideoTrack(opts, video);
  streamOptions.addAll(videoStreamOpts);

  // Check subtitles
  final subtitleStreamOpts = processSubtitles(tracks.textTracks.build());
  streamOptions.addAll(subtitleStreamOpts);

  // Check audio tracks
  final audioStreamOpts = processAudioTracks(opts, tracks.audioTracks.build());
  streamOptions.addAll(audioStreamOpts);

  final buffer = <String>[];
  buffer.add('ffmpeg -i "');
  if (opts.isBluray()) {
    buffer.add('bluray:');
  }
  buffer.add('$filename" \\');

  if (opts.isBluray()) {
    buffer.add(' -playlist ${opts.blurayPlaylist}\\');
  }

  var outputFilename = '';
  if (opts.mediaType == MediaType.movie) {
    final movieTitle = extractMovieTitle(
        filename,
        (MovieOverridesBuilder()
              ..imdbId = opts.imdbId
              ..name = opts.name
              ..tmdbId = opts.tmdbId
              ..year = opts.year)
            .build());
    streamOptions.add((GlobalMetadataBuilder()
          ..name = 'title'
          ..value = movieTitle.name)
        .build());
    outputFilename = makeMovieOutputName(
        isHdr: video.isHDR,
        letterPrefix: opts.movieOutputLetterPrefix,
        movie: movieTitle,
        outputFolder: opts.outputFolder,
        targetResolution: opts.targetResolution ?? video.videoResolution);
  } else {
    TvEpisode tvEpisode = extractTvEpisode(
        filename,
        (TvOverridesBuilder()
              ..name = opts.name
              ..tmdbId = opts.tmdbId
              ..tvdbId = opts.tvdbId
              ..year = opts.year)
            .build());
    outputFilename = makeTvOutputName(
        episode: tvEpisode,
        isHdr: video.isHDR,
        outputFolder: opts.outputFolder,
        targetResolution: opts.targetResolution ?? video.videoResolution);
  }

  for (final opt in streamOptions) {
    buffer.add(' ${opt.toString()} \\');
  }
  buffer.add(outputFilename);

  return buffer.build();
}

BuiltMap<AudioFormat, AudioTrackWrapper> filterTracks(
    {required BuiltList<AudioTrack> tracks, Language? language}) {
  final log = Logger('filterTracks');
  log.info('Filtering audio tracks for [${language?.iso}]');

  final Map<AudioFormat, AudioTrackWrapper> tracksByFormat = {};

  for (int i = 0; i < tracks.length; i++) {
    final AudioTrack t = tracks[i];
    if (t.title != null && t.title!.toLowerCase().contains('commentary')) {
      log.fine('Skipping commentary track #$i: "${t.title}"');
      continue;
    }
    final trackLang = t.language;
    if (language != null && trackLang != null && !language.matches(trackLang)) {
      log.fine('Skipping audio track #$i ($trackLang). Need: $language.');
      continue;
    }
    final af = t.toAudioFormat();
    tracksByFormat[af] = AudioTrackWrapper(i, t);
  }

  return BuiltMap.of(tracksByFormat);
}

List<StreamOption> processAudioTracks(SuggestOptions opts, BuiltList<AudioTrack> tracks) {
  final log = Logger('processAudioTracks');

  log.info('Analyzing ${tracks.length} audio tracks.');

  // Organize audio tracks by format and filter out any commentary tracks.
  // If a specific target language was request, filter out tracks in other languages.
  final BuiltMap<AudioFormat, AudioTrackWrapper> tracksByFormat =
      filterTracks(tracks: tracks, language: opts.language);
  if (tracksByFormat.length == 0) {
    throw const NoTracksFoundException(TrackType.audio);
  }
  for (final entry in tracksByFormat.entries) {
    final track = entry.value;
    log.fine('Found ${entry.key}: track #${track.orderId} '
        '[${track.track.language}], "${track.track.title}"');
  }

  final streamOpts = <StreamOption>[];

  // Find the best lossless format.
  var streamCount = 0;
  final audioFinder = AudioFinder((af) => af..tracksByFormat = tracksByFormat.toBuilder());

  log.info('Looking for best lossless track...');
  final srcLossless = audioFinder.bestLossless();
  if (srcLossless != null) {
    log.info('Copying ${srcLossless.format} (track #${srcLossless.orderId}) '
        '[${srcLossless.track.language}] to track #$streamCount');
    streamOpts.addAll([
      (StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = srcLossless.orderId
            ..dstStreamId = streamCount)
          .build(),
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..isDefault = true)
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..name = 'title'
            ..value = srcLossless.format.name)
          .build(),
    ]);
    streamCount++;
  }

  // Find the best audio source track for the main multichannel audio track.
  log.info('Looking for best source for main multichannel audio track...');
  final srcEAC3 = audioFinder.bestForEAC3();

  if (srcEAC3.format == AudioFormat.mono || srcEAC3.format == AudioFormat.stereo) {
    // No multichannel audio tracks available, so skip dealing with multichannel audio entirely
    // and include only this track.
    log.fine('Only available source is ${srcEAC3.format.name} (track #$streamCount)');
    streamOpts.addAll([
      (StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = srcEAC3.orderId
            ..dstStreamId = streamCount)
          .build(),
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..isDefault = (streamCount == 0))
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..name = 'title'
            ..value = 'AAC (${srcEAC3.format.name})')
          .build(),
    ]);
  } else {
    // Multichannel audio tracks.
    //
    // Next track should be Dolby Digital Plus or Dolby Digital, if possible.
    // Prefer using a Dolby Digital Plus or Dolby Digital track as the source for the Dolby
    // Digital track.
    AudioFormat firstTrackFormat = AudioFormat.unknown;
    if (srcEAC3.format == AudioFormat.dolbyDigitalPlus ||
        srcEAC3.format == AudioFormat.dolbyDigital) {
      // Note: ffmpeg EAC3 encoder can't handle > 5.1 channels.
      if (srcEAC3.track.channels != null && srcEAC3.track.channels! > 6) {
        // Force transcoding to 5.1
        log.info('Source is ${srcEAC3.format} (track ${srcEAC3.orderId}) with '
            '${srcEAC3.track.channels}, but ffmpeg only supports 5.1. Transcoding '
            'to 5.1.');
        firstTrackFormat = AudioFormat.dolbyDigitalPlus;
        streamOpts.add((AudioStreamConvertBuilder()
              ..inputFileId = 0
              ..srcStreamId = srcEAC3.orderId
              ..dstStreamId = streamCount
              ..format = AudioFormat.dolbyDigitalPlus
              ..channels = 6
              ..kbRate = maxAudioKbRate(srcEAC3.track, 384))
            .build());
      } else {
        // Already 5.1 or lower.
        firstTrackFormat = srcEAC3.format;
        log.info('Copying ${srcEAC3.format.name} (track #${srcEAC3.orderId}) '
            '[${srcEAC3.track.language}] #$streamCount.');
        streamOpts.add((StreamCopyBuilder()
              ..trackType = TrackType.audio
              ..inputFileId = 0
              ..srcStreamId = srcEAC3.orderId
              ..dstStreamId = streamCount)
            .build());
      }
    } else {
      // Source track is not Dolby Digital Plus or Dolby Digital, so transcode.
      firstTrackFormat = AudioFormat.dolbyDigitalPlus;

      // Note: ffmpeg EAC3 encoder can't handle > 5.1 channels.
      var channels = srcEAC3.track.channels;
      if (srcEAC3.track.channels != null && srcEAC3.track.channels! > 6) {
        channels = 6;
      }

      log.info('Transcoding ${srcEAC3.format} (track #${srcEAC3.orderId}) to '
          '[${srcEAC3.track.language}] ${AudioFormat.dolbyDigitalPlus} in #$streamCount');
      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = srcEAC3.orderId
            ..dstStreamId = streamCount
            ..format = AudioFormat.dolbyDigitalPlus
            ..channels = channels
            ..kbRate = maxAudioKbRate(srcEAC3.track, 384))
          .build());
    }
    streamOpts.addAll([
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..isDefault = (streamCount == 0))
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..name = 'title'
            ..value = firstTrackFormat.name)
          .build(),
    ]);
    streamCount++;

    // Find the best audio source track for the multichannel AAC track.
    log.info('Looking for best source multi-channel AAC...');
    final srcAacMulti = audioFinder.bestForMultiChannelAAC();
    if (srcAacMulti.format == AudioFormat.aacMulti) {
      log.info('Copying ${srcAacMulti.format.name} (track #${srcAacMulti.orderId}) to '
          '[${srcAacMulti.track.language}] track #$streamCount.');
      streamOpts.add((StreamCopyBuilder()
            ..trackType = TrackType.audio
            ..inputFileId = 0
            ..srcStreamId = srcAacMulti.orderId
            ..dstStreamId = streamCount)
          .build());
    } else {
      final kbRate = maxAudioKbRate(srcAacMulti.track, 384);
      final channels = (srcAacMulti.track.channels != null && srcAacMulti.track.channels! < 6)
          ? srcAacMulti.track.channels!
          : 6;
      log.info('Transcoding ${srcAacMulti.format.name} (track #${srcAacMulti.orderId}) '
          '[${srcAacMulti.track.language}] to AAC ($channels channels) $kbRate kbps as '
          'track #$streamCount.');
      streamOpts.add((AudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = srcAacMulti.orderId
            ..dstStreamId = streamCount
            ..format = AudioFormat.aacMulti
            ..channels = channels
            ..kbRate = kbRate)
          .build());
    }
    streamOpts.addAll([
      (StreamDispositionBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..isDefault = false)
          .build(),
      (StreamMetadataBuilder()
            ..trackType = TrackType.audio
            ..streamId = streamCount
            ..name = 'title'
            ..value = 'AAC (5.1)')
          .build(),
    ]);
    streamCount++;

    // Dolby Pro Logic II
    if (opts.generateDPL2) {
      streamOpts.add(ComplexFilter.fromFilter('[0:a]aresample=matrix_encoding=dplii[a]'));
      // Find the best audio source track for the Dolby Pro Logic II AAC track.
      final srcDPL2 = audioFinder.bestForDolbyProLogic2();
      final kbRate = maxAudioKbRate(srcDPL2.track, 256);
      log.info('Transcoding ${srcDPL2.format.name} (track #${srcDPL2.orderId}) to '
          'AAC (Dolby Pro Logic II) $kbRate kbps as track #$streamCount.');
      streamOpts.add((DolbyProLogicAudioStreamConvertBuilder()
            ..inputFileId = 0
            ..srcStreamId = srcDPL2.orderId
            ..dstStreamId = streamCount
            ..format = AudioFormat.stereo
            ..channels = 2
            ..kbRate = kbRate)
          .build());
      streamOpts.addAll([
        (StreamDispositionBuilder()
              ..trackType = TrackType.audio
              ..streamId = streamCount
              ..isDefault = false)
            .build(),
        (StreamMetadataBuilder()
              ..trackType = TrackType.audio
              ..streamId = streamCount
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
  final streamOpts = <StreamOption>[];

  log.info('Analyzing ${subtitles.length} subtitle tracks.');
  final subLangs = Set.unmodifiable(['en', 'eng', 'es', 'esp', 'fr', 'fra', 'de', 'deu']);
  var destStreamId = 0;
  for (final i in Iterable.generate(subtitles.length)) {
    final TextTrack tt = subtitles[i];
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
  final streamOpts = <StreamOption>[];

  // Check if we need to apply a scaling filter.
  if (opts.targetResolution == VideoResolution.uhd && video.width < 3840) {
    if (!opts.forceUpscaling) {
      throw UpscalingRequiredException(opts.targetResolution!, video.width);
    }
    log.info('Upscaling from width of ${video.width} to ${opts.targetResolution!.name}.');
    streamOpts.add(ScaleFilter.withDefaultHeight(3840));
    // Convert to H.265
    streamOpts.add((VideoStreamConvertBuilder()
          ..inputFileId = 0
          ..srcStreamId = 0
          ..dstStreamId = 0)
        .build());
  } else if (opts.targetResolution == VideoResolution.hd && video.width > 1920) {
    log.info('Downscaling from width of ${video.width} to ${opts.targetResolution!.name}.');
    streamOpts.add(ScaleFilter.withDefaultHeight(1920));
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

Movie extractMovieTitle(String sourcePathname, MovieOverrides overrides) {
  final sourceFilename = p.basename(sourcePathname);

  var name = 'unknown';
  String? imdb, tmdb, year;

  // Try to identify the name and year of the movie.
  final regex = RegExp(r'^(?<name>(\w+[.]?)+?)[.]?(?<year>(19\d\d|20\d\d))?[.].*[.](mkv|mp4|m4v)$');
  final match = regex.firstMatch(sourceFilename);
  if (match != null) {
    final rawName = match.namedGroup('name');
    if (rawName != null) {
      name = rawName.replaceAll('.', ' ').trim();
      year = match.namedGroup('year');
    }
  }

  name = (overrides.name == null) ? name : overrides.name!;

  imdb = (overrides.imdbId == null) ? imdb : overrides.imdbId;
  tmdb = (overrides.tmdbId == null) ? tmdb : overrides.tmdbId;
  year = (overrides.year == null) ? year : overrides.year;

  name = name.capitalizeEveryWord;
  return (MovieBuilder()
        ..imdbId = imdb
        ..name = name
        ..tmdbId = tmdb
        ..year = year)
      .build();
}

final _tvRegex = RegExp(
    r'(?<title>(\w)+(([.]|\s+)(\w)+)*)([.]|\s+)[Ss](?<season>\d\d)[Ee](?<episode>\d\d)[.].*');

TvSeries extractTvSeries(String sourcePathname, {String? yearOverride}) {
  final sourceFilename = p.basename(sourcePathname);

  var name = 'unknown';
  final match = _tvRegex.firstMatch(sourceFilename);
  if (match != null) {
    final rawTitle = match.namedGroup('title');
    if (rawTitle != null) {
      name = rawTitle.replaceAll('.', ' ').trim();
    }
  }

  return (TvSeriesBuilder()
        ..name = name
        ..year = yearOverride)
      .build();
}

TvEpisode extractTvEpisode(String sourcePathname, TvOverrides overrides) {
  final sourceFilename = p.basename(sourcePathname);

  var seriesTitle = 'unknown';
  var season = 1;
  var episode = 1;

  final match = _tvRegex.firstMatch(sourceFilename);
  if (match != null) {
    final rawTitle = match.namedGroup('title');
    if (rawTitle != null) {
      seriesTitle = rawTitle.replaceAll('.', ' ').trim();
    }
    final rawSeason = match.namedGroup('season');
    if (rawSeason != null) {
      season = int.parse(rawSeason);
    }
    final rawEpisode = match.namedGroup('episode');
    if (rawEpisode != null) {
      episode = int.parse(rawEpisode);
    }
  }

  seriesTitle = (overrides.name == null) ? seriesTitle : overrides.name!;

  return (TvEpisodeBuilder()
        ..season = season
        ..episodeNumber = episode
        ..series = (TvSeriesBuilder()
          ..name = seriesTitle
          ..tmdbShowId = overrides.tmdbId
          ..tvdbShowId = overrides.tvdbId
          ..year = overrides.year))
      .build();
}

final _movieTitleStopWords = BuiltSet<String>(['a', 'an', 'the']);
final _movieNumberRegex = RegExp(r'[0-9]');

String getMovieTitleFirstLetter(String title) {
  final titleWords = title.toLowerCase().split(' ');
  var firstLetter = titleWords[0][0];

  for (final w in titleWords) {
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

String makeMovieOutputName(
    {required Movie movie,
    bool isHdr = false,
    bool letterPrefix = false,
    String? outputFolder,
    VideoResolution? targetResolution}) {
  final baseNameBuffer = StringBuffer(movie.asFullName());

  final fileNameBuffer = StringBuffer(baseNameBuffer);
  if (targetResolution != null) {
    fileNameBuffer.write(' - ${targetResolution.toSizeName()}');
  }
  if (isHdr) {
    fileNameBuffer.write('-HDR');
  }
  fileNameBuffer.write('.mkv');

  final firstLetter = (letterPrefix) ? getMovieTitleFirstLetter(movie.name) : '';

  return p.join(outputFolder ?? '', firstLetter, '"${baseNameBuffer.toString()}"',
      '"${fileNameBuffer.toString()}"');
}

String makeTvOutputName(
    {required TvEpisode episode,
    bool isHdr = false,
    String? outputFolder,
    VideoResolution? targetResolution}) {
  final StringBuffer buffer = StringBuffer(episode.asFullName());

  buffer.write(' [');
  buffer.write(targetResolution!.toSizeName());
  if (isHdr) {
    buffer.write(' HDR');
  }
  buffer.write(']');
  buffer.write('.mkv');

  final season = 'season${episode.season}';

  return p.join(
      outputFolder ?? '', '"${episode.series.asFullName()}"', season, '"${buffer.toString()}"');
}

int maxAudioKbRate(AudioTrack track, int defaultMaxKbRate) {
  if (track.bitRateMode == BitRateMode.variable) {
    return defaultMaxKbRate;
  }

  if (track.bitRateLimit != null) {
    final kbRateLimit = track.bitRateLimit! ~/ 1024;
    return (kbRateLimit < defaultMaxKbRate) ? kbRateLimit : defaultMaxKbRate;
  }

  return defaultMaxKbRate;
}

////////////////////
// Classes
////////////////////

class SuggestFlags {
  static const String blurayPlaylist = 'bluray_playlist';
  static const String dpl2 = 'dpl2';
  static const String file = 'file';
  static const String fileMode = 'file_mode';
  static const String force = 'force';
  static const String language = 'lang';
  static const String name = 'name';
  static const String outputFolder = 'output_folder';
  static const String preferLossless = 'prefer_lossless';
  static const String targetResolution = 'target_resolution';
  static const String year = 'year';
}

abstract class BaseSuggestCommand extends Command {
  final log = Logger('BaseSuggestcommand');

  String getDefaultOutputFolder();
  MediaType getMediaType();
  SuggestOptions addOptions(SuggestOptions opts);

  // [run] may also return a Future.
  @override
  void run() async {
    if (globalResults?['verbose']) {
      Logger.root.level = Level.ALL;
    }

    final argResults = this.argResults;
    if ((argResults == null) || (argResults.rest.isEmpty)) {
      throw const MissingRequiredArgumentException('filename');
    }

    final parentArgs = parent!.argResults!;

    final outputFolder = parentArgs[SuggestFlags.outputFolder] ?? getDefaultOutputFolder();
    final outputFilename = parentArgs[SuggestFlags.file];

    final outputFileMode =
        OutputFileMode.values.byNameDefault(parentArgs[SuggestFlags.fileMode], OutputFileMode.fail);

    if (outputFilename != null) {
      final outputFile = File(outputFilename);
      if (outputFile.existsSync() && outputFileMode == OutputFileMode.fail) {
        log.severe('Output file already exists: $outputFilename. Use --${SuggestFlags.fileMode} '
            'to append to it or overwrite it.');
        return;
      }
    }

    final language = Language.byIso(parentArgs[SuggestFlags.language]);

    log.fine('Flags:');
    log.fine('  ${SuggestFlags.blurayPlaylist} = ${parentArgs[SuggestFlags.blurayPlaylist]}');
    log.fine('  ${SuggestFlags.force} = ${parentArgs[SuggestFlags.force]}');
    log.fine('  ${SuggestFlags.dpl2} = ${parentArgs[SuggestFlags.dpl2]}');
    log.fine('  ${SuggestFlags.language} = $language');
    log.fine('  ${SuggestFlags.name} = ${parentArgs[SuggestFlags.name]}');
    log.fine('  ${SuggestFlags.preferLossless} = ${parentArgs[SuggestFlags.preferLossless]}');
    log.fine('  ${SuggestFlags.targetResolution} = ${parentArgs[SuggestFlags.targetResolution]}');
    log.fine('  ${SuggestFlags.year} = ${parentArgs[SuggestFlags.year]}');

    var opts = SuggestOptions.withDefaults(
        blurayPlaylist: parentArgs[SuggestFlags.blurayPlaylist],
        force: parentArgs[SuggestFlags.force],
        dpl2: parentArgs[SuggestFlags.dpl2],
        language: language,
        mediaType: getMediaType(),
        name: parentArgs[SuggestFlags.name],
        outputFile: outputFilename,
        outputFileMode: outputFileMode,
        outputFolder: outputFolder,
        preferLossless: parentArgs[SuggestFlags.preferLossless],
        targetResolution: VideoResolution.byNameOrAlias(parentArgs[SuggestFlags.targetResolution]),
        year: parentArgs[SuggestFlags.year]);
    opts = addOptions(opts);

    final mediainfoRunner = MediainfoRunner(mediainfoBinary: globalResults?['mediainfo_bin']);

    final output = makeOutputSink(opts);

    for (final fileGlob in argResults.rest) {
      final f = opts.isBluray()
          ? makeFileForBluRay(fileGlob, opts.blurayPlaylist!)
          : makeFileForGlob(fileGlob);

      if (!f.existsSync()) {
        throw FileNotFoundException(f.path);
      }
      log.info('Found file: ${f.path}');

      final TrackList tracks = await getTrackList(mediainfoRunner, f.path);
      try {
        final suggestedCmdline = processFile(opts, f.path, tracks);
        suggestedCmdline.forEach(output.writeln);
        output.writeln();
      } on SuggestException catch (e) {
        log.severe('***** Error processing ${f.path}: $e');
      }
    }

    await output.close();
  }

  Future<TrackList> getTrackList(MediainfoRunner runner, String filename) async {
    log.info('Running mediainfo on $filename...');
    final MediaRoot root = await runner.run(filename);
    if (root.media.trackList.tracks.isEmpty) {
      throw InvalidMetadataException('no tracks found', filename);
    }

    final TrackList tl = root.media.trackList;
    if (tl.generalTrack == null) {
      throw InvalidMetadataException('no General track found', filename);
    }
    if (tl.audioTracks.isEmpty) {
      throw InvalidMetadataException('no audio tracks found', filename);
    }
    if (tl.videoTracks.isEmpty) {
      throw InvalidMetadataException('no video tracks found', filename);
    }

    return tl;
  }

  IOSink makeOutputSink(SuggestOptions opts) {
    if (opts.outputFile != null) {
      final outputFile = File(opts.outputFile!);
      if (outputFile.existsSync()) {
        if (opts.outputFileMode != OutputFileMode.append &&
            opts.outputFileMode != OutputFileMode.overwrite) {
          throw OutputFileExistsException(opts.outputFile!, SuggestFlags.fileMode);
        }
      }

      final openMode = (opts.outputFileMode == OutputFileMode.append)
          ? FileMode.writeOnlyAppend
          : FileMode.writeOnly;

      return outputFile.openWrite(mode: openMode);
    }

    return stdout;
  }

  File makeFileForBluRay(String dirName, String playlist) {
    final blurayFilename = '$dirName/BDMV/PLAYLIST/$playlist.mpls';
    log.info('Looking for BluRay playlist: $blurayFilename');
    return File(blurayFilename);
  }

  File makeFileForGlob(String glob) => File(glob);
}
