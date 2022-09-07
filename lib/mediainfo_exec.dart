import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:logging/logging.dart';
import 'package:process_run/shell.dart';

const mediainfoBinMac = '/usr/local/bin/mediainfo';
const mediainfoBinLinux = '/usr/bin/mediainfo';

class MediainfoException implements Exception {
  final String message;
  final int exitCode;
  final String? stdout;
  final String? stderr;

  const MediainfoException(this.message, this.exitCode, this.stdout, this.stderr);

  @override
  String toString() => '$message. Exit code: $exitCode.';
}

Future<MediaRoot> parseMediainfo(String filename, {String? mediainfoBinary}) async {
  final log = Logger('parseMediainfo');

  String mediainfo = mediainfoBinary ?? (Platform.isMacOS ? mediainfoBinMac : mediainfoBinLinux);
  var mediainfoCmdArgs = ['--Output=JSON', '"$filename"'];

  String cmdMsg = '$mediainfo ${mediainfoCmdArgs.join(" ")}';
  log.fine('Running $cmdMsg');
  ProcessResult result = await Process.run(mediainfo, mediainfoCmdArgs);
  if (result.exitCode > 0) {
    throw MediainfoException(
        'mediainfo execution failed with code ${result.exitCode}.'
        'Command: $cmdMsg.',
        result.exitCode,
        result.stdout,
        result.stderr);
  }

  log.fine('Successfully executed: $cmdMsg');
  log.fine('Result: ${result.exitCode}');
  log.fine('STDOUT: ${result.stdout.toString()}');
  log.fine('STDERR: ${result.stderr.toString()}');

  Map<String, dynamic> mediaMap = jsonDecode(result.stdout.toString());
  return MediaRoot.fromJson(mediaMap);
}

Future<MediaRoot> runMediainfo(String filename, {String? mediainfoBinary}) async {
  final log = Logger('runMediainfo');

  var stdoutController = ShellLinesController();
  var stderrController = ShellLinesController();
  var shell = Shell(
      stdout: stdoutController.sink,
      stderr: stderrController.sink,
      verbose: true,
      commandVerbose: false,
      commentVerbose: false);

  StringBuffer stdout = StringBuffer();
  stdoutController.stream.listen((event) {
    stdout.writeln(event);
  });
  StringBuffer stderr = StringBuffer();
  stderrController.stream.listen((event) {
    stderr.writeln(event);
  });

  String mediainfo = mediainfoBinary ?? (Platform.isMacOS ? mediainfoBinMac : mediainfoBinLinux);
  String cmdMessage = '$mediainfo --Output=JSON "$filename"';
  try {
    List<ProcessResult> results = await shell.run(cmdMessage);
    if (results.first.exitCode > 0) {
      throw MediainfoException(
          'mediainfo execution failed with code ${results.first.exitCode}.'
          'Command: $cmdMessage',
          results.first.exitCode,
          stdout.toString(),
          stderr.toString());
    }

    log.fine('Successfully executed: $cmdMessage');
  } on ShellException catch (e) {
    log.warning('Error running shell command: ${e.toString()}');
    rethrow;
  }

  Map<String, dynamic> mediaMap = jsonDecode(stdout.toString());
  try {
    return MediaRoot.fromJson(mediaMap);
  } catch (e) {
    log.severe('Error loading MediaRoot from JSON for $filename');
    log.severe('mediainfo stdout: ${stdout.toString()}');
    log.severe('mediainfo stderr: ${stderr.toString()}');
    rethrow;
  }
}
