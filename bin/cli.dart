// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ffmpeg_helper/cli/exceptions.dart';
import 'package:ffmpeg_helper/cli/suggest.dart';
import 'package:ffmpeg_helper/cli/summary.dart';
import 'package:ffmpeg_helper/mediainfo_runner.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var runner = CommandRunner('cli', 'A tool to help generate ffmpeg commandlines.')
    ..addCommand(SummaryCommand())
    ..addCommand(SuggestCommand());
  runner.argParser.addFlag('verbose', abbr: 'v', negatable: false, defaultsTo: false);
  runner.argParser.addOption('mediainfo_bin',
      defaultsTo: Platform.isMacOS ? mediainfoBinMac : mediainfoBinLinux);

  try {
    await runner.run(args);
  } on UsageException catch (error) {
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  } on CliException catch (e) {
    print('Error! $e');
    exit(1);
  }
}
