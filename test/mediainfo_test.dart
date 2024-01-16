import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models.dart';
import 'package:test/test.dart';

void main() {
  group('Media model', () {
    test('can parse audio only track', () async {
      final file = File('test_resources/audiotrack_full.json');
      final Map<String, dynamic> trackMap = jsonDecode(await file.readAsString());
      final track = AudioTrack.fromJson(trackMap);

      expect(track.id, '2');
      expect(track.channels, 8);
      expect(track.title, 'Atmos 7.1');
      expect(track.isDefault, true);
      expect(track.isForced, false);
    });

    test('can parse minimal required JSON', () async {
      final file = File('test_resources/media_minimal.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.ref, 'media_minimal.mkv');
      expect(mediaRoot.media.trackList.tracks, hasLength(5));
      expect(mediaRoot.media.trackList.audioTracks, hasLength(1));
      expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
      expect(mediaRoot.media.trackList.textTracks, hasLength(1));
      expect(mediaRoot.media.trackList.videoTracks, hasLength(1));

      final gt = mediaRoot.media.trackList.generalTrack;
      expect(gt, isNotNull);
      expect(gt!.title, isNotNull);
      expect(gt.title, 'Media Minimal');

      // const wantVideo = VideoTrack(TrackType.video, '1', 'V_MPEGH/ISO/HEVC',
      //     '6d86c4300aca4e9682e263cd7f89a4c4', '0', null, 'AVC', 1920, 800, null, null, 0);
      const wantVideo = VideoTrack.createFromParams(
          codecId: 'V_MPEGH/ISO/HEVC',
          format: 'AVC',
          id: '1',
          height: 800,
          streamOrder: '0',
          typeOrder: 0,
          width: 1920,
          uniqueId: '6d86c4300aca4e9682e263cd7f89a4c4');

      final vt = mediaRoot.media.trackList.videoTracks[0];
      expect(vt, isNotNull);
      expect(vt, wantVideo);
    });

    test('can parse JSON from non-linear video editor', () async {
      final file = File('test_resources/media_editor.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.ref, '2020-10-31 14-31-09.mkv');
      expect(mediaRoot.media.trackList.tracks, hasLength(3));
      expect(mediaRoot.media.trackList.generalTrack, isNotNull);
      expect(mediaRoot.media.trackList.audioTracks, hasLength(1));
      expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
    });

    test('can parse extra big JSON', () async {
      final file = File('test_resources/media.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.ref, 'media-large.mkv');
      expect(mediaRoot.media.trackList.tracks, hasLength(42));
      expect(mediaRoot.media.trackList.generalTrack, isNotNull);
      expect(mediaRoot.media.trackList.audioTracks, hasLength(2));
      expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
      expect(mediaRoot.media.trackList.textTracks, hasLength(37));
      expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
    });

    test('can parse H.265 2160p HDR data', () async {
      final file = File('test_resources/media-x265-2160p-HDR.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.ref, 'The.Media.2160p.X265.HDR/The.Media.2160p.X265.HDR.mkv');
      expect(mediaRoot.media.trackList.tracks, hasLength(34));
      expect(mediaRoot.media.trackList.generalTrack, isNotNull);
      expect(mediaRoot.media.trackList.audioTracks, hasLength(4));
      expect(mediaRoot.media.trackList.menuTracks, hasLength(1));
      expect(mediaRoot.media.trackList.textTracks, hasLength(27));
      expect(mediaRoot.media.trackList.videoTracks, hasLength(1));
    });

    test('can parse without unique id', () async {
      final file = File('test_resources/mediainfo-full-01.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.trackList.tracks, hasLength(3));
      expect(mediaRoot.media.trackList.videoTracks[0].format, 'HEVC');
      expect(mediaRoot.media.trackList.videoTracks[0].codecId, 'hev1');
      expect(mediaRoot.media.trackList.videoTracks[0].width, 1920);
      expect(mediaRoot.media.trackList.videoTracks[0].isHDR, isFalse);

      expect(mediaRoot.media.trackList.audioTracks[0].format, 'AAC');
      expect(mediaRoot.media.trackList.audioTracks[0].channels, 6);
      expect(mediaRoot.media.trackList.audioTracks[0].toAudioFormat(), AudioFormat.aacMulti);

      expect(mediaRoot.media.trackList.menuTracks, hasLength(0));
      expect(mediaRoot.media.trackList.textTracks, hasLength(0));
    });

    test('can parse DTS-HD MA audio streams', () async {
      final file = File('test_resources/mediainfo-full-02.json');
      final Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
      final mediaRoot = MediaRoot.fromJson(mediaMap);

      expect(mediaRoot.media.trackList.tracks, hasLength(27));
      expect(mediaRoot.media.trackList.audioTracks[0].toAudioFormat(), AudioFormat.trueHD);
      expect(mediaRoot.media.trackList.audioTracks[1].toAudioFormat(), AudioFormat.dolbyDigital);
      expect(mediaRoot.media.trackList.audioTracks[2].toAudioFormat(), AudioFormat.dtsHDMA);
      expect(mediaRoot.media.trackList.audioTracks[0].bitRateMode, BitRateMode.variable);
      expect(mediaRoot.media.trackList.audioTracks[1].bitRateMode, BitRateMode.constant);
      expect(mediaRoot.media.trackList.audioTracks[2].bitRateMode, BitRateMode.variable);
    });
  });
}
