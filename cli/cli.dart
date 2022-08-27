import 'dart:io';

import 'mediainfo_exec.dart';

import 'package:args/command_runner.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final log = Logger('main()');

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

class MissingAudioSourceException implements Exception {
  final String purpose;
  final List<AudioFormat> availableFormats;
  const MissingAudioSourceException(this.purpose, this.availableFormats);

  @override
  String toString() => 'Unable to find an appropriate audio source track for $purpose. '
      'Only found the following formats: ${availableFormats.join(", ")}';
}

class MissingRequiredArgumentException implements Exception {
  final String argument;
  const MissingRequiredArgumentException(this.argument);

  @override
  String toString() => 'Missing required argument: $argument.';
}

class InvalidMetadataException implements Exception {
  final String message;
  final String filename;
  const InvalidMetadataException(this.message, this.filename);

  @override
  String toString() => 'Invalid media metadata: $message';
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

class SummaryCommand extends Command {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "summary";
  @override
  final description = "Show summary information about a media file.";

  final log = Logger('SummaryCommand');

  SummaryCommand() {
    // Set command specific arguments and flags.
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

    String filename = argResults.rest[0];
    if (filename.isEmpty) {
      throw const MissingRequiredArgumentException('filename');
    }

    MediaRoot root = await parseMediainfo(filename);
    if (root.media.trackList.tracks.isEmpty) {
      throw InvalidMetadataException('no tracks found', filename);
    }

    TrackList tl = root.media.trackList;
    if (tl.generalTrack == null) {
      throw InvalidMetadataException('no General track found', filename);
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln('Container format: ${tl.generalTrack?.format}');
    buffer.writeln('Video count: ${tl.generalTrack?.videoCount}');
    buffer.writeln('Audio count: ${tl.generalTrack?.audioCount}');
    buffer.writeln('Text count : ${tl.generalTrack?.textCount}');
    buffer.writeln('Menu count : ${tl.generalTrack?.menuCount}');
    buffer.writeln('');
    buffer.writeln('VIDEO');
    buffer.writeln('-----');
    List<VideoTrack> videos = tl.videoTracks.toList();
    videos.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (VideoTrack v in videos) {
      buffer.writeln('StreamOrder: ${v.streamOrder}');
      buffer.writeln('ID: ${v.id}');
      buffer.writeln('Format: ${v.format}');
      buffer.writeln('Codec: ${v.codecId}');
      buffer.writeln('');
    }
    buffer.writeln('AUDIO');
    buffer.writeln('-----');
    List<AudioTrack> audios = tl.audioTracks.toList();
    audios.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (AudioTrack a in audios) {
      buffer.writeln('StreamOrder: ${a.streamOrder}');
      buffer.writeln('ID: ${a.id}');
      buffer.writeln('Format: ${a.format}');
      buffer.writeln('Commercial name: ${a.formatCommercialName}');
      buffer.writeln('Format: ${a.codecId}');
      buffer.writeln('Channels: ${a.channels}');
      buffer.writeln('Channels: ${a.channelLayout}');
      buffer.writeln('Language: ${a.language}');
      buffer.writeln('Default: ${a.isDefault}');
      buffer.writeln('Forced: ${a.isForced}');
      buffer.writeln('Title: ${a.title}');
      buffer.writeln('');
    }
    buffer.writeln('TEXT');
    buffer.writeln('----');
    List<TextTrack> texts = tl.textTracks.toList();
    texts.sort((a, b) {
      int cmp = a.typeOrder.compareTo(b.typeOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (TextTrack t in texts) {
      buffer.writeln('Type Order: ${t.typeOrder}');
      buffer.writeln('ID: ${t.id}');
      buffer.writeln('Format: ${t.format}');
      buffer.writeln('Codec ID: ${t.codecId}');
      buffer.writeln('Title: ${t.title}');
      buffer.writeln('Language: ${t.language}');
      buffer.writeln('Default: ${t.isDefault}');
      buffer.writeln('Forced: ${t.isForced}');
      buffer.writeln('');
    }
    print(buffer.toString());
  }
}

class SuggestCommand extends Command {
  // The [name] and [description] properties must be defined by every
  // subclass.
  @override
  final name = "suggest";
  @override
  final description = "Suggests commandline flags for ffmpeg.";

  final log = Logger('SuggestComment');

  SuggestCommand() {
    // Set command specific arguments and flags.
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
      runMediaInfo(filename);
    }
  }

  void runMediaInfo(String filename) async {
    log.info('Running mediainfo...');
    MediaRoot root = await parseMediainfo(filename);
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

    StringBuffer buffer = StringBuffer();
    buffer.writeln('ffmpeg -i $filename \\');
    buffer.writeln('-filter_complex "[0:a]aresample=matrix_encoding=dplii[a]" \\');

    VideoTrack video = tl.videoTracks.first;
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
    log.info('Analyzing ${tl.textTracks.length} subtitle tracks...');
    var subLangs = Set.unmodifiable(['en', 'eng', 'es', 'esp', 'fr', 'fra', 'de', 'deu']);
    var subtitleTracks = <TextTrackWrapper>[];
    for (int i = 0; i < tl.textTracks.length; i++) {
      TextTrack tt = tl.textTracks[i];
      if (!subLangs.contains(tt.language)) {
        continue;
      }
      subtitleTracks.add(TextTrackWrapper(i, tt));
    }
    for (int i = 0; i < subtitleTracks.length; i++) {
      TextTrackWrapper tt = subtitleTracks[i];
      buffer.writeln('-map 0:s:${tt.orderId} -c:0:s:$i copy \\');
      if (tt.track.language != null) {
        buffer.write('-metadata:s:s:$i language=${langToISO639_2(tt.track.language!)}');
      }
      buffer.writeln(' -metadata:s:s:$i handler="${tt.track.handler}" \\');
    }

    // Sort audio tracks by streamOrder.
    List<AudioTrack> audios = tl.audioTracks.toList();
    audios.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });

    // Organize audio tracks by format and filter out any commentary tracks.
    Map<AudioFormat, AudioTrackWrapper> tracksByFormat = {};
    for (int i = 0; i < audios.length; i++) {
      AudioTrack t = audios[i];
      if (t.title != null && t.title!.toLowerCase().contains('commentary')) {
        continue;
      }
      var af = t.toAudioFormat();
      tracksByFormat[af] = AudioTrackWrapper(i, t, af);
    }

    // Find the best audio source track for the main multichannel audio track.
    AudioTrackWrapper audioSource = findBestMultiChannelSource(tracksByFormat);

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

  String processMonoStereoAudio(AudioTrackWrapper audioSource) {
    log.fine('Only available source is ${audioSource.format.name} at orderId '
        '${audioSource.orderId}. Copying to orderId 0.');
    var buffer = StringBuffer();
    buffer.writeln(copyAudio(audioSource.orderId, 0));
    buffer.writeln('-disposition:a:0 default \\');
    return buffer.toString();
  }

  String processMultiChannelAudio(
      Map<AudioFormat, AudioTrackWrapper> tracksByFormat, AudioTrackWrapper source) {
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

  AudioTrackWrapper findBestMultiChannelSource(Map<AudioFormat, AudioTrackWrapper> tracksByFormat) {
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

  AudioTrackWrapper findBestSourceForAAC(Map<AudioFormat, AudioTrackWrapper> tracksByFormat) {
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

  AudioTrackWrapper findBestSourceForDPL2(Map<AudioFormat, AudioTrackWrapper> tracksByFormat) {
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

class AudioTrackWrapper {
  final int orderId;
  final AudioTrack track;
  final AudioFormat format;

  const AudioTrackWrapper(this.orderId, this.track, this.format);
}

class TextTrackWrapper {
  final int orderId;
  final TextTrack track;
  const TextTrackWrapper(this.orderId, this.track);
}
