// ignore_for_file: avoid_print

import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:ffmpeg_helper/src/models/enums.dart';

class SuggestMovieCommand extends BaseSuggestCommand {
  static const String defaultOutputFolder = r'$MOVIES';

  static const String flagImdb = 'imdb_id';
  static const String flagMovieLetterPrefix = 'output_movie_letter';
  static const String flagTmdb = 'tmdb_id';

  @override
  final name = 'movie';
  @override
  final description = 'Suggests commandline flags using ffmpeg to convert a movie.';

  SuggestMovieCommand() {
    argParser.addFlag(flagMovieLetterPrefix,
        help: 'Prefix output directory with the first letter of the movie title.',
        defaultsTo: true,
        negatable: true);

    argParser.addOption(flagImdb, help: 'IMDB movie id', valueHelp: 'ID', aliases: ['imdb']);
    argParser.addOption(flagTmdb, help: 'TMDB movie id', valueHelp: 'ID', aliases: ['tmdb']);
  }

  @override
  String getDefaultOutputFolder() => defaultOutputFolder;

  @override
  MediaType getMediaType() => MediaType.movie;

  @override
  SuggestOptions addOptions(SuggestOptions opts) {
    return opts.rebuild((o) => o
      ..movieOutputLetterPrefix = argResults?[flagMovieLetterPrefix]
      ..imdbId = argResults?[flagImdb]
      ..tmdbId = argResults?[flagTmdb]);
  }
}
