import 'exceptions.dart';
import 'mediainfo_exec.dart';

import 'package:args/command_runner.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:logging/logging.dart';

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
