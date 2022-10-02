import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ffmpeg_helper/cli/suggest.dart';
import 'package:ffmpeg_helper/mediainfo_exec.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'exceptions.dart';

class SuggestCommand extends Command {
  static const String defaultOutputMovies = r'$MOVIES';
  static const String defaultOutputTV = r'$TV';

  @override
  final name = "suggest";
  @override
  final description = "Suggests commandline flags for ffmpeg.";

  final log = Logger('SuggestComment');

  SuggestCommand() {
    argParser.addOption('media_type',
        abbr: 'm',
        help: 'Type of media file. Controls output naming behavior.',
        allowed: MediaType.names(),
        defaultsTo: MediaType.movie.name);

    argParser.addOption('output_folder',
        abbr: 'o',
        help: '''Base output folder. Defaults to "$defaultOutputMovies" when --media_type is
${MediaType.movie.name} and "$defaultOutputTV" when --media_type is ${MediaType.tv.name}.''');

    argParser.addOption('target_resolution',
        abbr: 't',
        help: '''Target video resolution for the output file. Defaults to matching the
resolution of the input file. Will warn when trying to upconvert.''',
        allowed: VideoResolution.allNames());

    argParser.addFlag('force',
        abbr: 'f', help: 'Force upconversion.', defaultsTo: false, negatable: true);

    argParser.addFlag('dpl2',
        help: 'Generate Dolby Pro Logic II audio track.',
        defaultsTo: true,
        negatable: true,
        aliases: ['dolbyprologic2', 'dplii', 'dolbyprologicii']);
  }

  // [run] may also return a Future.
  @override
  void run() async {
    if (globalResults?['verbose']) {
      Logger.root.level = Level.ALL;
    }

    var argResults = this.argResults;
    if (argResults == null) {
      throw const MissingRequiredArgumentException('filename');
    }

    for (var filename in argResults.rest) {
      if (filename.isEmpty) {
        throw const MissingRequiredArgumentException('filename');
      }

      final f = File(filename);
      if (!f.existsSync()) {
        throw FileNotFoundException(filename);
      }

      TrackList tracks = await getTrackList(filename);
      processFile(filename, tracks);
    }
  }

  Future<TrackList> getTrackList(String filename) async {
    log.info('Running mediainfo...');
    MediaRoot root = await runMediainfo(filename);
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

  void processFile(String filename, TrackList tracks) async {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('ffmpeg -i $filename \\');
    buffer.writeln('-filter_complex "[0:a]aresample=matrix_encoding=dplii[a]" \\');

    VideoTrack video = tracks.videoTracks.first;
    String movieTitle = extractMovieTitle(filename);
    String outputFilename = makeOutputName(filename, movieTitle, video.sizeName, video.isHDR);

    if (video.format == 'HEVC') {
      log.fine('Video already encoded with H.265');
      buffer.writeln('-map 0:v -c:v copy \\');
    } else {
      log.fine('Need to convert video to H.264');
      buffer.writeln('-vf scale=1920:-1 \\');
      buffer.writeln('-map 0:v -c:v hevc -vtag hvc1 \\');
    }

    // Subtitles
    log.info('Analyzing ${tracks.textTracks.length} subtitle tracks...');
    var subLangs = Set.unmodifiable(['en', 'eng', 'es', 'esp', 'fr', 'fra', 'de', 'deu']);
    var subtitleTracks = <wrappers.TextTrack>[];
    for (int i = 0; i < tracks.textTracks.length; i++) {
      TextTrack tt = tracks.textTracks[i];
      if (!subLangs.contains(tt.language)) {
        continue;
      }
      subtitleTracks.add(wrappers.TextTrack(i, tt));
    }
    for (int i = 0; i < subtitleTracks.length; i++) {
      wrappers.TextTrack tt = subtitleTracks[i];
      buffer.writeln('-map 0:s:${tt.orderId} -c:s:$i copy \\');
      if (tt.track.language != null) {
        buffer.write('-metadata:s:s:$i language=${langToISO639_2(tt.track.language!)}');
      }
      buffer.writeln(' -metadata:s:s:$i handler="${tt.track.handler}" \\');
    }

    // Sort audio tracks by streamOrder.
    List<AudioTrack> audios = tracks.audioTracks.toList();
    audios.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });

    // Organize audio tracks by format and filter out any commentary tracks.
    Map<AudioFormat, wrappers.AudioTrack> tracksByFormat = {};
    for (int i = 0; i < audios.length; i++) {
      AudioTrack t = audios[i];
      if (t.title != null && t.title!.toLowerCase().contains('commentary')) {
        continue;
      }
      var af = t.toAudioFormat();
      tracksByFormat[af] = wrappers.AudioTrack(i, t);
    }

    // Find the best audio source track for the main multichannel audio track.
    wrappers.AudioTrack audioSource = findBestMultiChannelSource(tracksByFormat);

    if (audioSource.format == AudioFormat.mono || audioSource.format == AudioFormat.stereo) {
      // Skip dealing with multichannel audio and include only this track.
      buffer.write(processMonoStereoAudio(audioSource));
    } else {
      // Multichannel audio tracks.
      buffer.write(processMultiChannelAudio(tracksByFormat, audioSource));
    }

    // Additional metadata
    buffer.writeln('-metadata title="$movieTitle" \\');

    buffer.writeln(outputFilename);

    print('Suggested commandline:');
    print(buffer.toString());
  }

  String processMonoStereoAudio(wrappers.AudioTrack audioSource) {
    log.fine('Only available source is ${audioSource.format.name} at orderId '
        '${audioSource.orderId}. Copying to orderId 0.');
    var buffer = StringBuffer();
    buffer.writeln(copyAudio(audioSource.orderId, 0));
    buffer.writeln('-disposition:a:0 default \\');
    return buffer.toString();
  }

  String processMultiChannelAudio(
      Map<AudioFormat, wrappers.AudioTrack> tracksByFormat, wrappers.AudioTrack source) {
    var buffer = StringBuffer();
    AudioFormat firstTrackFormat;
    if (source.format == AudioFormat.dolbyDigitalPlus ||
        source.format == AudioFormat.dolbyDigital) {
      firstTrackFormat = source.format;
      log.fine('Copying ${source.format.name} (track #${source.orderId}) to track #0.');
      buffer.writeln(copyAudio(source.orderId, 0));
    } else {
      // Transcode
      firstTrackFormat = AudioFormat.dolbyDigitalPlus;
      int kbRate = maxAudioKbRate(source.track, 384);
      log.fine('Transcoding ${source.format.name} (track #${source.orderId}) '
          'to E-AC-3 as track #0.');
      buffer.writeln('-map 0:a:${source.orderId} -c:a:0 eac3 -b:a ${kbRate}k -ac:a:0 6 \\');
    }

    // Find the best audio source track for the multichannel AAC track.
    var audioSource = findBestSourceForAAC(tracksByFormat);
    if (audioSource.format == AudioFormat.aacMulti) {
      log.fine('Copying ${audioSource.format.name} (track #${audioSource.orderId}) to track #1.');
      buffer.writeln(copyAudio(audioSource.orderId, 1));
    } else {
      // Transcode
      int kbRate = maxAudioKbRate(audioSource.track, 384);
      log.fine('Transcoding ${audioSource.format.name} (track #${audioSource.orderId}) '
          'to AAC (5.1) as track #1.');
      buffer.writeln('-map 0:a:${audioSource.orderId} -c:a:1 aac -b:a ${kbRate}k -ac:a:1 6 \\');
    }

    // Find the best audio source track for the Dolby Pro Logic II AAC track.
    audioSource = findBestSourceForDPL2(tracksByFormat);
    int kbRate = maxAudioKbRate(audioSource.track, 256);
    log.fine('Transcoding ${audioSource.format.name} (track #${audioSource.orderId}) to '
        'AAC (Dolby Pro Logic II) as track #2.');
    buffer.writeln(
        '-map:a:${audioSource.orderId} "[a]" -c:a:2 aac -b:a ${kbRate}k -ac:a:2 2 -strict 2 \\');

    buffer.writeln('-disposition:a:0 default \\');
    buffer.writeln('-disposition:a:1 0 \\');
    buffer.writeln('-disposition:a:2 0 \\');

    buffer.writeln('-metadata:s:a:0 title="${firstTrackFormat.name}" \\');
    buffer.writeln('-metadata:s:a:1 title="AAC (5.1)" \\');
    buffer.writeln('-metadata:s:a:2 title="AAC (Dolby Pro Logic II)" \\');

    return buffer.toString();
  }

  wrappers.AudioTrack findBestMultiChannelSource(
      Map<AudioFormat, wrappers.AudioTrack> tracksByFormat) {
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }

    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      // If there is no lossless or DTS formats present, then this is the
      // best we have.
      if (!tracksByFormat.containsKey(AudioFormat.trueHD) &&
          !tracksByFormat.containsKey(AudioFormat.dtsHDMA) &&
          !tracksByFormat.containsKey(AudioFormat.dtsX) &&
          !tracksByFormat.containsKey(AudioFormat.dts)) {
        return tracksByFormat[AudioFormat.aacMulti]!;
      }

      if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
        return tracksByFormat[AudioFormat.trueHD]!;
      }
      if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
        return tracksByFormat[AudioFormat.dtsHDMA]!;
      }
      if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
        return tracksByFormat[AudioFormat.dtsX]!;
      }
      return tracksByFormat[AudioFormat.dts]!;
    }

    if (tracksByFormat.containsKey(AudioFormat.stereo)) {
      return tracksByFormat[AudioFormat.stereo]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.mono)) {
      return tracksByFormat[AudioFormat.mono]!;
    }

    throw MissingAudioSourceException('primary multichannel', tracksByFormat.keys.toList());
  }

  wrappers.AudioTrack findBestSourceForAAC(Map<AudioFormat, wrappers.AudioTrack> tracksByFormat) {
    // If we already have multichannel AAC, use that.
    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      return tracksByFormat[AudioFormat.aacMulti]!;
    }

    // If we have a lossless format, use that.
    if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
      return tracksByFormat[AudioFormat.trueHD]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
      return tracksByFormat[AudioFormat.dtsHDMA]!;
    }

    // If we don't have multichannel AAC or lossless, fall back on DD+, DD, DTS:X, or DTS.
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
      return tracksByFormat[AudioFormat.dtsX]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dts)) {
      return tracksByFormat[AudioFormat.dts]!;
    }

    throw MissingAudioSourceException('AAC (5.1)', tracksByFormat.keys.toList());
  }

  wrappers.AudioTrack findBestSourceForDPL2(Map<AudioFormat, wrappers.AudioTrack> tracksByFormat) {
    // If we have a lossless format, use that.
    if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
      return tracksByFormat[AudioFormat.trueHD]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
      return tracksByFormat[AudioFormat.dtsHDMA]!;
    }

    // If we don't have lossless, use DD+, DD, DTS:X, DTS, or multichannel AAC.
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
      return tracksByFormat[AudioFormat.dtsX]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dts)) {
      return tracksByFormat[AudioFormat.dts]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      return tracksByFormat[AudioFormat.aacMulti]!;
    }

    throw MissingAudioSourceException('AAC (Dolby Pro Logic II)', tracksByFormat.keys.toList());
  }

  int maxAudioKbRate(AudioTrack track, int defaultMaxKbRate) {
    if (track.bitRateLimit != null) {
      int kbRateLimit = track.bitRateLimit! ~/ 1024;
      return (kbRateLimit < defaultMaxKbRate) ? kbRateLimit : defaultMaxKbRate;
    }

    return defaultMaxKbRate;
  }

  String copyAudio(int srcStreamId, int destStreamId) =>
      '-map 0:a:$srcStreamId -c:a:$destStreamId copy \\';

  String extractMovieTitle(String sourcePathname) {
    var sourceFilename = p.basename(sourcePathname);

    // Try to identify the name of the movie.
    var regex = RegExp(r'^(?<name>(\w+[.]?)+)[.](19\d\d|20\d\d).*[.](mkv|mp4|m4v)$');
    var match = regex.firstMatch(sourceFilename);
    if (match != null) {
      final name = match.namedGroup('name');
      if (name != null) {
        return name.replaceAll('.', ' ');
      }
    }

    return "unknown";
  }

  String makeOutputName(String sourcePathname, String movieName, String? resolution, bool isHDR) {
    var sourceFilename = p.basename(sourcePathname);

    // Try to identify the year the movie was released.
    int? year;
    RegExp regex = RegExp(r'\w+[.](?<year>19\d\d|20\d\d)');
    RegExpMatch? match = regex.firstMatch(sourceFilename);
    if (match != null) {
      final releaseYear = match.namedGroup('year');
      if (releaseYear != null) {
        year = int.parse(releaseYear);
      }
    }

    var pathBuffer = StringBuffer(movieName);
    if (year != null) {
      pathBuffer.write(' ($year)');
    }

    var filenameBuffer = StringBuffer(movieName);
    if (year != null) {
      filenameBuffer.write(' ($year)');
    }
    if (resolution != null) {
      filenameBuffer.write(' - $resolution');
    }
    filenameBuffer.write('.mkv');

    return p.join('"${pathBuffer.toString()}"', '"${filenameBuffer.toString()}"');
  }
}

String langToISO639_2(String lang) {
  switch (lang) {
    case 'de':
    case 'deu':
      return 'deu';
    case 'en':
    case 'eng':
      return 'eng';
    case 'es':
    case 'esp':
      return 'esp';
    case 'fr':
    case 'fra':
      return 'fra';
    default:
      return lang;
  }
}
