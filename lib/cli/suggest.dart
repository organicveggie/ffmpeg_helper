// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ffmpeg_helper/mediainfo_runner.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';

import '../src/cli/exceptions.dart';
import '../src/cli/suggest.dart';

class SuggestCommand extends Command {
  static const String defaultOutputMovies = r'$MOVIES';
  static const String defaultOutputTV = r'$TV';

  static const String flagDPL2 = 'dpl2';
  static const String flagExperimental = 'experimental';
  static const String flagForce = 'force';
  static const String flagMediaType = 'media_type';
  static const String flagMovieLetterPrefix = 'output_movie_letter';
  static const String flagOutputFolder = 'output_folder';
  static const String flagTargetResolution = 'target_resolution';

  @override
  final name = "suggest";
  @override
  final description = "Suggests commandline flags for ffmpeg.";

  final log = Logger('SuggestComment');

  SuggestCommand() {
    argParser.addOption(flagMediaType,
        abbr: 'm',
        help: 'Type of media file. Controls output naming behavior.',
        allowed: MediaType.names(),
        defaultsTo: MediaType.movie.name);

    argParser.addOption(flagOutputFolder,
        abbr: 'o',
        help: '''Base output folder. Defaults to "$defaultOutputMovies" when --media_type is
${MediaType.movie.name} and "$defaultOutputTV" when --media_type is ${MediaType.tv.name}.''');

    argParser.addOption(flagTargetResolution,
        abbr: 't',
        help: '''Target video resolution for the output file. Defaults to matching the
resolution of the input file. Will warn when trying to upconvert.''',
        allowed: VideoResolution.allNames());

    argParser.addFlag(flagForce,
        abbr: 'f', help: 'Force upscaling.', defaultsTo: false, negatable: true);

    argParser.addFlag(flagDPL2,
        help: 'Generate Dolby Pro Logic II audio track.',
        defaultsTo: true,
        negatable: true,
        aliases: ['dolbyprologic2', 'dplii', 'dolbyprologicii']);

    argParser.addFlag(flagMovieLetterPrefix,
        help: 'Prefix output directory the first letter of the movie title.',
        defaultsTo: true,
        negatable: true);
  }

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

    var opts = SuggestOptions.fromStrings(
        force: argResults[flagForce],
        dpl2: argResults[flagDPL2],
        mediaType: argResults[flagMediaType],
        movieOutputLetterPrefix: argResults[flagMovieLetterPrefix],
        outputFolder: argResults[flagOutputFolder],
        targetResolution: argResults[flagTargetResolution]);

    var mediainfoRunner = MediainfoRunner(mediainfoBinary: globalResults?['mediainfo_bin']);

    for (var fileGlob in argResults.rest) {
      for (var file in Glob(fileGlob).listSync()) {
        final f = File(file.path);
        if (!f.existsSync()) {
          throw FileNotFoundException(file.path);
        }

        TrackList tracks = await getTrackList(mediainfoRunner, file.path);
        var suggestedCmdline = processFile(opts, file.path, tracks);

        print('Suggested commandline:');
        print(suggestedCmdline);
      }
    }
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
}
