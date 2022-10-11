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
  static const String _defaultOutputMovies = r'$MOVIES';
  static const String _defaultOutputTV = r'$TV';

  static const String flagDPL2 = 'dpl2';
  static const String flagExperimental = 'experimental';
  static const String flagFile = 'file';
  static const String flagFileOverwrite = 'file_overwrite';
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
        allowed: MediaType.values.names(),
        defaultsTo: MediaType.movie.name);

    argParser.addOption(flagFile,
        abbr: 'f',
        help: '''Write the suggested commandlines to the specified file instead of stdout. Will fail
if the destination file already exists, unless --$flagFileOverwrite is specified.''');

    argParser.addOption(flagOutputFolder,
        abbr: 'o',
        help: '''Base output folder. Defaults to "$_defaultOutputMovies" when --media_type is
${MediaType.movie.name} and "$_defaultOutputTV" when --media_type is ${MediaType.tv.name}.''');

    argParser.addOption(flagTargetResolution,
        abbr: 't',
        help: '''Target video resolution for the output file. Defaults to matching the
resolution of the input file. Will warn when trying to upconvert.''',
        allowed: VideoResolution.namesAndAliases());

    argParser.addFlag(flagFileOverwrite,
        help: 'Overwrite output file, if it exists.', defaultsTo: false, negatable: true);

    argParser.addFlag(flagForce, help: 'Force upscaling.', defaultsTo: false, negatable: true);

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

    final mediaType = MediaType.values.byNameDefault(argResults[flagMediaType], MediaType.movie);
    var outputFolder = argResults[flagOutputFolder];
    if (outputFolder == null) {
      if (mediaType == MediaType.movie) {
        outputFolder = _defaultOutputMovies;
      } else {
        outputFolder = _defaultOutputTV;
      }
    }

    var outputFilename = argResults[flagFile];
    var overwriteOutputFile = argResults[flagFileOverwrite];

    if (argResults[flagFile] != null) {
      var outputFile = File(outputFilename);
      if (outputFile.existsSync() && !overwriteOutputFile) {
        log.severe('Output file already exists: $outputFilename. Use --$flagFileOverwrite to '
            'overwrite the file.');
        return;
      }
    }

    final opts = SuggestOptions.withDefaults(
        force: argResults[flagForce],
        dpl2: argResults[flagDPL2],
        mediaType: mediaType,
        movieOutputLetterPrefix: argResults[flagMovieLetterPrefix],
        outputFile: outputFilename,
        outputFolder: outputFolder,
        overwriteOutputFile: overwriteOutputFile,
        targetResolution: VideoResolution.byNameOrAlias(argResults[flagTargetResolution]));

    var mediainfoRunner = MediainfoRunner(mediainfoBinary: globalResults?['mediainfo_bin']);

    var output = makeOutputSink(opts);

    for (var fileGlob in argResults.rest) {
      for (var file in Glob(fileGlob).listSync()) {
        final f = File(file.path);
        if (!f.existsSync()) {
          throw FileNotFoundException(file.path);
        }
        log.info('Found file: ${f.path}');

        TrackList tracks = await getTrackList(mediainfoRunner, file.path);
        var suggestedCmdline = processFile(opts, file.path, tracks);

        for (var line in suggestedCmdline) {
          output.writeln(line);
        }
        output.writeln();
      }
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
      if (outputFile.existsSync() && !opts.overwriteOutputFile) {
        throw OutputFileExistsException(opts.outputFile!, flagFileOverwrite);
      }
      return outputFile.openWrite(mode: FileMode.writeOnly);
    }

    return stdout;
  }
}
