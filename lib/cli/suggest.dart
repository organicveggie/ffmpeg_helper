// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/mediainfo_runner.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;
import 'package:logging/logging.dart';

import '../src/cli/audio_finder.dart';
import '../src/cli/enums.dart';
import '../src/cli/exceptions.dart';
import '../src/cli/suggest.dart';

class SuggestCommand extends Command {
  static const String defaultOutputMovies = r'$MOVIES';
  static const String defaultOutputTV = r'$TV';

  static const String flagDPL2 = 'dpl2';
  static const String flagExperimental = 'experimental';
  static const String flagForce = 'force';
  static const String flagMediaType = 'media_type';
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
        allowed: MediaType.names(),
        defaultsTo: MediaType.movie.name);

    argParser.addOption(flagOutputFolder,
        abbr: 'o',
        help: '''Base output folder. Defaults to "$defaultOutputMovies" when --media_type is
${MediaType.movie.name} and "$defaultOutputTV" when --media_type is ${MediaType.tv.name}.''');

    argParser.addOption(flagTargetResolution,
        abbr: 't',
        help: '''Target video resolution for the output file. Defaults to matching the
resolution of the input file. Will warn when trying to upconvert.''',
        allowed: VideoResolution.allNames());

    argParser.addFlag(flagForce,
        abbr: 'f', help: 'Force upscaling.', defaultsTo: false, negatable: true);

    argParser.addFlag(flagDPL2,
        help: 'Generate Dolby Pro Logic II audio track.',
        defaultsTo: true,
        negatable: true,
        aliases: ['dolbyprologic2', 'dplii', 'dolbyprologicii']);

    argParser.addFlag(flagExperimental,
        help: 'Run in experimental mode.', defaultsTo: false, negatable: true);
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

    var opts = SuggestOptions.fromStrings(
        force: argResults[flagForce],
        dpl2: argResults[flagDPL2],
        mediaType: argResults[flagMediaType],
        outputFolder: argResults[flagOutputFolder],
        targetResolution: argResults[flagTargetResolution]);

    var mediainfoRunner = MediainfoRunner(mediainfoBinary: globalResults?['mediainfo_bin']);

    for (var filename in argResults.rest) {
      if (filename.isEmpty) {
        throw const MissingRequiredArgumentException('filename');
      }

      final f = File(filename);
      if (!f.existsSync()) {
        throw FileNotFoundException(filename);
      }

      TrackList tracks = await getTrackList(mediainfoRunner, filename);
      var suggestedCmdline = '';
      if (argResults[flagExperimental]) {
        suggestedCmdline = processFileExperimentalMode(opts, filename, tracks);
      } else {
        suggestedCmdline = await processFile(opts, filename, tracks);
      }

      print('Suggested commandline:');
      print(suggestedCmdline);
    }
  }

  Future<TrackList> getTrackList(MediainfoRunner runner, String filename) async {
    log.info('Running mediainfo...');
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

  Future<String> processFile(SuggestOptions opts, String filename, TrackList tracks) async {
    // Check for upconversion.
    VideoTrack video = tracks.videoTracks.first;
    if (video.width <= 1920 && opts.targetResolution == VideoResolution.uhd) {
      if (!opts.forceUpscaling) {
        throw UpscalingRequiredException(opts.targetResolution!, video.width);
      }
      log.info('Upconverting from width of ${video.width} to ${opts.targetResolution!.name}.');
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln('ffmpeg -i $filename \\');

    var movieTitle = extractMovieTitle(filename);
    String outputFilename = makeOutputName(movieTitle, video);

    if (video.format == 'HEVC') {
      log.fine('Video already encoded with H.265');
      buffer.writeln('-map 0:v -c:v copy \\');
    } else {
      log.fine('Need to convert video to H.265');
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
      buffer.write('-metadata:s:s:$i language=${langToISO639_2(tt.track.language)}');
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
    var audioFinder = AudioFinder((af) => af..tracksByFormat.addAll(tracksByFormat));
    var audioSource = audioFinder.bestForEAC3();

    if (audioSource.format == AudioFormat.mono || audioSource.format == AudioFormat.stereo) {
      // Skip dealing with multichannel audio and include only this track.
      buffer.write(processMonoStereoAudio(audioSource));
    } else {
      // Multichannel audio tracks.
      if (opts.generateDPL2) {
        buffer.writeln('-filter_complex "[0:a]aresample=matrix_encoding=dplii[a]" \\');
      }
      buffer.write(processMultiChannelAudio(opts, audioFinder, audioSource));
    }

    // Additional metadata
    buffer.writeln('-metadata title="$movieTitle" \\');

    buffer.writeln(outputFilename);

    return buffer.toString();
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
      SuggestOptions opts, AudioFinder finder, wrappers.AudioTrack source) {
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
    buffer.writeln('-disposition:a:0 default \\');
    buffer.writeln('-metadata:s:a:0 title="${firstTrackFormat.name}" \\');

    // Find the best audio source track for the multichannel AAC track.
    var audioSource = finder.bestForMultiChannelAAC();
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
    buffer.writeln('-disposition:a:1 0 \\');
    buffer.writeln('-metadata:s:a:1 title="AAC (5.1)" \\');

    if (opts.generateDPL2) {
      // Find the best audio source track for the Dolby Pro Logic II AAC track.
      audioSource = finder.bestForDolbyProLogic2();
      int kbRate = maxAudioKbRate(audioSource.track, 256);
      log.fine('Transcoding ${audioSource.format.name} (track #${audioSource.orderId}) to '
          'AAC (Dolby Pro Logic II) as track #2.');
      buffer.writeln(
          '-map:a:${audioSource.orderId} "[a]" -c:a:2 aac -b:a ${kbRate}k -ac:a:2 2 -strict 2 \\');
      buffer.writeln('-disposition:a:2 0 \\');
      buffer.writeln('-metadata:s:a:2 title="AAC (Dolby Pro Logic II)" \\');
    }

    return buffer.toString();
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
}
