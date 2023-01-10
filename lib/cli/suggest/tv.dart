// ignore_for_file: avoid_print

import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:ffmpeg_helper/src/models/enums.dart';

class SuggestTvCommand extends BaseSuggestCommand {
  static const String defaultOutputFolder = r'$TV';

  static const String flagTmdb = 'tmdb_show_id';
  static const String flagTvdb = 'tvdb_show_id';

  @override
  final name = 'tv';
  @override
  final description = 'Suggests commandline flags using ffmpeg to convert a TV episode.';

  SuggestTvCommand() {
    argParser.addOption(flagTmdb, help: 'TMDB show id', valueHelp: 'ID', aliases: ['tmdb']);
    argParser.addOption(flagTvdb, help: 'TVDB show id', valueHelp: 'ID', aliases: ['tvdb']);
  }

  @override
  String getDefaultOutputFolder() => defaultOutputFolder;

  @override
  MediaType getMediaType() => MediaType.tv;

  @override
  SuggestOptions addOptions(SuggestOptions opts) {
    return opts.rebuild((o) => o
      ..tmdbShowId = argResults?[flagTmdb]
      ..tvdbShowId = argResults?[flagTvdb]);
  }
}
