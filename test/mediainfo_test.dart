import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:test/test.dart';

void main() {
  test('Media model can parse audio only track', () async {
    final file = File('test_resources/audiotrack_full.json');
    Map<String, dynamic> trackMap = jsonDecode(await file.readAsString());
    var track = AudioTrack.fromJson(trackMap);

    expect(track.id, '2');
    expect(track.channels, 8);
    expect(track.title, 'Atmos 7.1');
    expect(track.isDefault, true);
    expect(track.isForced, false);
  });

  test('Media model can parse minimal required JSON', () async {
    final file = File('test_resources/media_minimal.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);

    expect(mediaRoot.media.ref, 'media_minimal.mkv');
    expect(mediaRoot.media.trackList.tracks, hasLength(5));
    expect(mediaRoot.media.trackList.audioTracks, hasLength(1));
    expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
    expect(mediaRoot.media.trackList.textTracks, hasLength(1));
    expect(mediaRoot.media.trackList.videoTracks, hasLength(1));

    var gt = mediaRoot.media.trackList.generalTrack;
    expect(gt, isNotNull);
    expect(gt!.title, isNotNull);
    expect(gt.title, 'Media Minimal');
  });
  test('Media model can parse JSON from non-linear video editor', () async {
    final file = File('test_resources/media_editor.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);

    expect(mediaRoot.media.ref, '2020-10-31 14-31-09.mkv');
    expect(mediaRoot.media.trackList.tracks, hasLength(3));
    expect(mediaRoot.media.trackList.generalTrack, isNotNull);
    expect(mediaRoot.media.trackList.audioTracks, hasLength(1));
    expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
  });
  test('Media model can parse extra big JSON', () async {
    final file = File('test_resources/media.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);

    expect(mediaRoot.media.ref, 'media-large.mkv');
    expect(mediaRoot.media.trackList.tracks, hasLength(42));
    expect(mediaRoot.media.trackList.generalTrack, isNotNull);
    expect(mediaRoot.media.trackList.audioTracks, hasLength(2));
    expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
    expect(mediaRoot.media.trackList.textTracks, hasLength(37));
    expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
  });
  test('Media model can parse H.265 2160p HDR data', () async {
    final file = File('test_resources/media-x265-2160p-HDR.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);

    expect(mediaRoot.media.ref, 'The.Media.2160p.X265.HDR/The.Media.2160p.X265.HDR.mkv');
    expect(mediaRoot.media.trackList.tracks, hasLength(34));
    expect(mediaRoot.media.trackList.generalTrack, isNotNull);
    expect(mediaRoot.media.trackList.audioTracks, hasLength(4));
    expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
    expect(mediaRoot.media.trackList.textTracks, hasLength(27));
    expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
  });
}
