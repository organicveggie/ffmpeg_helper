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
      VideoResolution? targetResolution,
      String? imdbId,
      String? tmdbId,
      String? tvdbId,
      String? year}) {
    return (SuggestOptionsBuilder()
          ..forceUpscaling = force
          ..generateDPL2 = dpl2
          ..imdbId = imdbId
          ..mediaType = mediaType
          ..movieOutputLetterPrefix = movieOutputLetterPrefix ?? false
          ..name = name
          ..outputFile = outputFile
          ..outputFileMode = outputFileMode ?? OutputFileMode.fail
          ..outputFolder = outputFolder
          ..targetResolution = targetResolution
          ..tmdbId = tmdbId
          ..tvdbId = tvdbId
          ..year = year)
        .build();
  }

  @override
  List<Object?> get props => [
        forceUpscaling,
        generateDPL2,
        imdbId,
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
  buffer.add('ffmpeg -i "$filename" \\');

  var outputFilename = '';
  if (opts.mediaType == MediaType.movie) {
    var overrides = (MovieOverridesBuilder()
          ..imdbId = opts.imdbId
          ..name = opts.name
          ..tmdbId = opts.tmdbId
          ..year = opts.year)
        .build();
    var movieTitle = extractMovieTitle(filename, overrides);
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
    var overrides = (TvOverridesBuilder()
          ..name = opts.name
          ..tmdbId = opts.tmdbId
          ..tvdbId = opts.tvdbId
          ..year = opts.year)
        .build();
    TvEpisode tvEpisode = extractTvEpisode(filename, overrides);
    outputFilename = makeTvOutputName(
        episode: tvEpisode,
        isHdr: video.isHDR,
        outputFolder: opts.outputFolder,
        targetResolution: opts.targetResolution ?? video.videoResolution);
  }

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
  var regex = RegExp(r'^(?<name>(\w+[.]?)+?)[.]?(?<year>(19\d\d|20\d\d))?[.].*[.](mkv|mp4|m4v)$');
  var match = regex.firstMatch(sourceFilename);
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
  var match = _tvRegex.firstMatch(sourceFilename);
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

  var match = _tvRegex.firstMatch(sourceFilename);
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

  var firstLetter = '';
  if (letterPrefix) {
    firstLetter = getMovieTitleFirstLetter(movie.name);
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

  buffer.write(' [');
  buffer.write(targetResolution!.toSizeName());
  if (isHdr) {
    buffer.write(' HDR');
  }
  buffer.write(']');
  buffer.write('.mkv');

  var season = 'season${episode.season}';

  return p.join(
      outputFolder ?? '', '"${episode.series.asFullName()}"', season, '"${buffer.toString()}"');
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

////////////////////
// Classes
////////////////////

class SuggestFlags {
  static const String dpl2 = 'dpl2';
  static const String file = 'file';
  static const String fileMode = 'file_mode';
  static const String force = 'force';
  static const String name = 'name';
  static const String outputFolder = 'output_folder';
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

    var argResults = this.argResults;
    if ((argResults == null) || (argResults.rest.isEmpty)) {
      throw const MissingRequiredArgumentException('filename');
    }

    var parentArgs = parent!.argResults!;

    var outputFolder = parentArgs[SuggestFlags.outputFolder] ?? getDefaultOutputFolder();
    var outputFilename = parentArgs[SuggestFlags.file];

    var outputFileMode =
        OutputFileMode.values.byNameDefault(parentArgs[SuggestFlags.fileMode], OutputFileMode.fail);

    if (outputFilename != null) {
      var outputFile = File(outputFilename);
      if (outputFile.existsSync() && outputFileMode == OutputFileMode.fail) {
        log.severe('Output file already exists: $outputFilename. Use --${SuggestFlags.fileMode} '
            'to append to it or overwrite it.');
        return;
      }
    }

    var opts = SuggestOptions.withDefaults(
        force: parentArgs[SuggestFlags.force],
        dpl2: parentArgs[SuggestFlags.dpl2],
        mediaType: getMediaType(),
        name: parentArgs[SuggestFlags.name],
        outputFile: outputFilename,
        outputFileMode: outputFileMode,
        outputFolder: outputFolder,
        targetResolution: VideoResolution.byNameOrAlias(parentArgs[SuggestFlags.targetResolution]),
        year: parentArgs[SuggestFlags.year]);
    opts = addOptions(opts);

    var mediainfoRunner = MediainfoRunner(mediainfoBinary: globalResults?['mediainfo_bin']);

    var output = makeOutputSink(opts);

    for (var fileGlob in argResults.rest) {
      final f = File(fileGlob);
      if (!f.existsSync()) {
        throw FileNotFoundException(fileGlob);
      }
      log.info('Found file: ${f.path}');

      TrackList tracks = await getTrackList(mediainfoRunner, f.path);
      var suggestedCmdline = processFile(opts, f.path, tracks);

      for (var line in suggestedCmdline) {
        output.writeln(line);
      }
      output.writeln();
    }

    await output.close();
  }

  Future<TrackList> getTrackList(MediainfoRunner runner, String filename) async {
    log.info('Running mediainfo on $filename...');
    MediaRoot root = await runner.run(filename);
    if (root.media.trackList.tracks.isEmpty) {
      throw InvalidMetadataException('no tracks found', filename);
    }

    TrackList tl = root.media.trackList;
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
      var outputFile = File(opts.outputFile!);
      if (outputFile.existsSync()) {
        if (opts.outputFileMode != OutputFileMode.append &&
            opts.outputFileMode != OutputFileMode.overwrite) {
          throw OutputFileExistsException(opts.outputFile!, SuggestFlags.fileMode);
        }
      }

      var openMode = FileMode.writeOnly;
      if (opts.outputFileMode == OutputFileMode.append) {
        openMode = FileMode.writeOnlyAppend;
      }

      return outputFile.openWrite(mode: openMode);
    }

    return stdout;
  }
}
