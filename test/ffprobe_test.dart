import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models/ffprobe.dart';
import 'package:test/test.dart';

void main() {
  test('model can process simple streams', () async {
    final file = File('test_resources/ffprobe-minimal.json');
    Map<String, dynamic> jsonMap = jsonDecode(await file.readAsString());

    var media = Media.fromJson(jsonMap);
    expect(media.streams, hasLength(2));
    expect(media.audioStreams, hasLength(1));
    expect(media.videoStreams, hasLength(1));

    var video = media.videoStreams[0];
    expect(video.index, 0);
    expect(video.colorSpace, isNull);
    expect(video.colorTransfer, isNull);
    expect(video.colorPrimaries, isNull);
    expect(video.isHDR, isFalse);
    expect(video.hdrName, 'SDR');
    expect(video.sizeName, '1080p');

    expect(video.disposition, isNotNull);
    expect(video.disposition!.def, isTrue);
    expect(video.disposition!.isDefault, isTrue);
    expect(video.disposition!.forced, isFalse);
    expect(video.disposition!.dub, isFalse);
    expect(video.disposition!.original, isFalse);

    expect(video.tags, isNotNull);
    expect(video.tags!.handlerName, 'VideoHandler');
    expect(video.tags!.language, 'und');

    var audio = media.audioStreams[0];
    expect(audio.index, 1);
    expect(audio.codecName, 'aac');
    expect(audio.sampleRate, 48000);
    expect(audio.channels, 6);
    expect(audio.bitRate, 224000);
    expect(audio.maxBitRate, 256000);
    expect(audio.bitRateKbps, 224);
    expect(audio.maxBitRateKbps, 256);

    expect(audio.disposition, isNotNull);
    expect(audio.disposition!.def, isTrue);
    expect(audio.disposition!.isDefault, isTrue);
    expect(audio.disposition!.forced, isFalse);
    expect(audio.disposition!.dub, isFalse);
    expect(audio.disposition!.original, isFalse);
    expect(audio.disposition!.original, isFalse);

    expect(audio.tags, isNotNull);
    expect(audio.tags!.handlerName, 'SoundHandler');
    expect(audio.tags!.language, 'eng');
  });

  test('model can process full set of streams', () async {
    final file = File('test_resources/ffprobe-full.json');
    Map<String, dynamic> jsonMap = jsonDecode(await file.readAsString());

    var media = Media.fromJson(jsonMap);
    expect(media.streams.length, 35);
  });
}
