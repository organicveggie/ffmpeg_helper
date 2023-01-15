// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';

import 'package:ffmpeg_helper/models.dart';

import 'suggest/movie.dart';
import 'suggest/tv.dart';
import '../src/cli/suggest.dart';

class SuggestCommand extends Command {
  @override
  final name = 'suggest';
  @override
  final description = 'Suggests commandline flags for ffmpeg.';

  final log = Logger('SuggestCommand');

  SuggestCommand() {
    argParser.addOption(SuggestFlags.file,
        abbr: 'f',
        help: 'Write the suggested commandlines to the specified file instead of stdout. Will fail '
            'if the destination file already exists, unless --${SuggestFlags.fileOverwrite} is '
            'specified.',
        valueHelp: 'TEXTFILE');

    argParser.addOption(SuggestFlags.name,
        help: 'Name of the movie or TV series. Default behavior is to try to extract the name from '
            'the filename.',
        valueHelp: 'NAME');

    argParser.addOption(SuggestFlags.outputFolder,
        abbr: 'o',
        help: 'Base output folder. Defaults to "${SuggestMovieCommand.defaultOutputFolder}" for '
            'movies and "${SuggestTvCommand.defaultOutputFolder}" for TV episodes.',
        valueHelp: 'FOLDER');

    argParser.addOption(
      SuggestFlags.targetResolution,
      abbr: 't',
      help: 'Target video resolution for the output file. Defaults to matching the resolution of '
          'the input file. Will warn when trying to upconvert.',
      valueHelp: 'RES',
      allowed: VideoResolution.namesAndAliases(),
    );

    argParser.addOption(SuggestFlags.year,
        abbr: 'y',
        help: 'Four digit year the content was released. Default is to try to deduce the year from '
            'the filename.',
        valueHelp: 'YYYY');

    argParser.addFlag(SuggestFlags.fileOverwrite,
        help: 'Overwrite output file, if it exists.', defaultsTo: false, negatable: true);

    argParser.addFlag(SuggestFlags.force,
        help: 'Force upscaling.', defaultsTo: false, negatable: true);

    argParser.addFlag(SuggestFlags.dpl2,
        help: 'Generate Dolby Pro Logic II audio track.',
        defaultsTo: true,
        negatable: true,
        aliases: ['dolbyprologic2', 'dplii', 'dolbyprologicii']);

    addSubcommand(SuggestMovieCommand());
    addSubcommand(SuggestTvCommand());
  }
}
