import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models.dart';
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

class MediainfoRunner {
  final String _binary;
  final _log = Logger('MediainfoRunner');

  MediainfoRunner({String? mediainfoBinary})
      : _binary = mediainfoBinary ?? (Platform.isMacOS ? mediainfoBinMac : mediainfoBinLinux);

  Future<MediaRoot> run(String filename) async {
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

    String cmdMessage = '$_binary --Output=JSON "$filename"';
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

      _log.fine('Successfully executed: $cmdMessage');
    } on ShellException catch (e) {
      _log.warning('Error running shell command: ${e.toString()}');
      rethrow;
    }

    Map<String, dynamic> mediaMap = jsonDecode(stdout.toString());
    try {
      return MediaRoot.fromJson(mediaMap);
    } catch (e) {
      _log.severe('Error loading MediaRoot from JSON for $filename');
      _log.severe('mediainfo stdout: ${stdout.toString()}');
      _log.severe('mediainfo stderr: ${stderr.toString()}');
      rethrow;
    }
  }
}
