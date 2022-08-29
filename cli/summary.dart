import 'dart:io';

import 'package:ffmpeg_helper/fixedprint.dart';

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

  static const detailedFlagName = 'detailed';

  final log = Logger('SummaryCommand');

  SummaryCommand() {
    argParser.addFlag(
      detailedFlagName,
      abbr: 'd',
    );
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

    final f = File(filename);
    if (!f.existsSync()) {
      throw FileNotFoundException(filename);
    }

    MediaRoot root = await parseMediainfo(filename);
    if (root.media.trackList.tracks.isEmpty) {
      throw InvalidMetadataException('no tracks found', filename);
    }

    TrackList tl = root.media.trackList;
    if (tl.generalTrack == null) {
      throw InvalidMetadataException('no General track found', filename);
    }

    // ===Normal Output===
    // All: StreamOrder Type TypeOrder Default Forced Language
    // VideoSummary: Format HDR Width Height
    // AudioSummary: CodecId Channels MaxBitRate(Kbps) AudioFormat Title
    // TextSummary: Formart Title

    //           1         2         3         4         5         6         7         8         9
    // 0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789
    // --|-|--|-|-|---|-----------|-|-----|----|-------------|--------------------------------------------|
    //  0 V  0 Y N   -        HEVC Y  3840 1600
    //  1 A  0 Y N  en    A_TRUEHD 8  7794       Dolby TrueHD        Atmos 7.1
    //  2 A  1 N N  en       A_AC3 6   640      Dolby Digital        AC-3 5.1
    //  3 A  2 N N  en       A_AC3 2   640      Dolby Digital        Philosopher Commentary
    // 10 T  1 N N  en       UTF-8               Stripped SRT

    bool isDetailed = argResults[detailedFlagName];
    StringBuffer buffer = StringBuffer();
    FixedPrinter fp =
        FixedPrinter(buffer, defaultAlign: Alignment.right, defaultOverflow: Overflow.ellipsis);

    buffer.writeln('Container format: ${tl.generalTrack?.format}');
    buffer.writeln('Video count: ${tl.generalTrack?.videoCount}');
    buffer.writeln('Audio count: ${tl.generalTrack?.audioCount}');
    buffer.writeln('Text count : ${tl.generalTrack?.textCount}');
    buffer.writeln('Menu count : ${tl.generalTrack?.menuCount}');
    buffer.writeln('');

    if (isDetailed) {
      buffer.writeln('VIDEO');
      buffer.writeln('-----');
    } else {
      fp.writeAll(const <Item>[
        Item('SO', width: 2),
        Item('T'),
        Item('#', width: 2),
        Item('D'),
        Item('F'),
        Item('Lng', width: 3),
        Item('Format', width: 11),
        Item('H'),
        Item('Width', width: 5),
        Item('Hght', width: 4)
      ], separator: '|');
      fp.writeln('');
      fp.repeatWrite('-', '|', const <int>[2, 1, 2, 1, 1, 3, 11, 1, 5, 4]);
      fp.writeln('');
    }
    List<VideoTrack> videos = tl.videoTracks.toList();
    videos.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (var i = 0; i < videos.length; i++) {
      VideoTrack v = videos[i];
      if (isDetailed) {
        buffer.writeln('StreamOrder: ${v.streamOrder}');
        buffer.writeln('ID: ${v.id}');
        buffer.writeln('Format: ${v.format}');
        buffer.writeln('Codec: ${v.codecId}');
        buffer.writeln('');
      } else {
        fp.writeAll(<Item>[
          Item(v.streamOrder, width: 2),
          Item('V'),
          Item(i.toString(), width: 2),
          Item('?'),
          Item('?'),
          Item('-', width: 3),
          Item(v.format, width: 11),
          Item(v.isHDR ? 'Y' : 'N'),
          Item(v.width.toString(), width: 5),
          Item(v.height.toString(), width: 4),
        ], separator: '|');
        fp.writeln('');
      }
    }

    if (isDetailed) {
      buffer.writeln('AUDIO');
      buffer.writeln('-----');
    } else {
      fp.writeln('');
      fp.writeAll(const <Item>[
        Item('SO', width: 2),
        Item('T'),
        Item('#', width: 2),
        Item('D'),
        Item('F'),
        Item('Lng', width: 3),
        Item('Codec', width: 11),
        Item('C'),
        Item('Kbps', width: 5),
        Item('Format', width: 18),
        Item('Title', width: 43),
      ], separator: '|');
      fp.writeln('');
      fp.repeatWrite('-', '|', const <int>[2, 1, 2, 1, 1, 3, 11, 1, 5, 18, 43]);
      fp.writeln('');
      //   |T| #|D|F|Lng|      Codec|C| Kbps|            Format| Title
      // --|-|--|-|-|---|-----------|-|-----|------------------|--------------------------------------------|
      //  1 A  0 Y N  en    A_TRUEHD 8  7794       Dolby TrueHD        Atmos 7.1
    }
    List<AudioTrack> audios = tl.audioTracks.toList();
    audios.sort((a, b) {
      int cmp = a.streamOrder.compareTo(b.streamOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (var i = 0; i < audios.length; i++) {
      AudioTrack a = audios[i];
      if (isDetailed) {
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
      } else {
        fp.writeAll(<Item>[
          Item(a.streamOrder, width: 2),
          Item('T'),
          Item(i.toString(), width: 2),
          Item(a.isDefault ? 'Y' : 'N'),
          Item(a.isForced ? 'Y' : 'N'),
          Item(a.language ?? '-', width: 3),
          Item(a.codecId ?? '-', width: 11),
          Item(a.channels == null ? '-' : a.channels.toString()),
          Item(a.bitRateMaxAsKbps == null ? '-' : a.bitRateMaxAsKbps.toString(), width: 5),
          Item(a.toAudioFormat().toString(), width: 18),
          Item(a.title ?? '-', width: 43)
        ], separator: '|');
        fp.writeln('');
      }
    }

    if (isDetailed) {
      buffer.writeln('TEXT');
      buffer.writeln('----');
    } else {
      fp.writeln('');
      fp.writeAll(const <Item>[
        Item('SO', width: 2),
        Item('T'),
        Item('#', width: 2),
        Item('D'),
        Item('F'),
        Item('Lng', width: 3),
        Item('Format', width: 11),
        Item('Title', width: 37),
      ], separator: '|');
      fp.writeln('');
      fp.repeatWrite('-', '|', const <int>[2, 1, 2, 1, 1, 3, 11, 37]);
      fp.writeln('');
      //   |T| #|D|F|Lng|     Format|                     Title|
      // --|-|--|-|-|---|-----------|--------------------------|
      // 10 T  1 N N  en       UTF-8               Stripped SRT
    }
    List<TextTrack> texts = tl.textTracks.toList();
    texts.sort((a, b) {
      int cmp = a.typeOrder.compareTo(b.typeOrder);
      return (cmp == 0) ? a.id.compareTo(b.id) : cmp;
    });
    for (var i = 0; i < texts.length; i++) {
      TextTrack t = texts[i];
      if (isDetailed) {
        buffer.writeln('Type Order: ${t.typeOrder}');
        buffer.writeln('ID: ${t.id}');
        buffer.writeln('Format: ${t.format}');
        buffer.writeln('Codec ID: ${t.codecId}');
        buffer.writeln('Title: ${t.title}');
        buffer.writeln('Language: ${t.language}');
        buffer.writeln('Default: ${t.isDefault}');
        buffer.writeln('Forced: ${t.isForced}');
        buffer.writeln('');
      } else {
        fp.writeAll(<Item>[
          Item('?', width: 2),
          Item('T'),
          Item(i.toString(), width: 2),
          Item(t.isDefault ? 'Y' : 'N'),
          Item(t.isForced ? 'Y' : 'N'),
          Item(t.language, width: 3),
          Item(t.format ?? '-', width: 11),
          Item(t.title ?? '-', width: 37),
        ], separator: '|');
        fp.writeln('');
      }
    }
    print(buffer.toString());
  }
}
