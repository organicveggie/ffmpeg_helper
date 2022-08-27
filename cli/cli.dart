// ignore_for_file: avoid_print

import 'dart:io';

import 'mediainfo_exec.dart';
import 'suggest.dart';
import 'summary.dart';

import 'package:args/command_runner.dart';
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

  runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  });
}
