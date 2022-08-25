import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:logging/logging.dart';

const mediainfoBinMac = '/usr/local/bin/mediainfo';
const mediainfoBinLinux = '/usr/bin/mediainfo';

class MediainfoException implements Exception {
  final String message;
  final int exitCode;
  final String? stdout;
  final String? stderr;

  const MediainfoException(
      this.message, this.exitCode, this.stdout, this.stderr);

  @override
  String toString() => '$message. Exit code: $exitCode.';
}

Future<MediaRoot> parseMediainfo(String filename,
    {String? mediainfoBinary}) async {
  final log = Logger('parseMediainfo');

  String mediainfo = mediainfoBinary ??
      (Platform.isMacOS ? mediainfoBinMac : mediainfoBinLinux);
  var mediainfoCmdArgs = ['--Output=JSON', filename];

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

  Map<String, dynamic> mediaMap = jsonDecode(result.stdout.toString());
  return MediaRoot.fromJson(mediaMap);
}
