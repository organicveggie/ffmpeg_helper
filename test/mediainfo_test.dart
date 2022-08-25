import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:test/test.dart';

void main() {
  test('Media model can parse minimal required JSON', () async {
    final file = File('test_resources/media_minimal.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);
    var media = mediaRoot.media;

    expect(media.ref, 'media_minimal.mkv');
  });
  test('Media model can parse JSON from non-linear video editor', () async {
    final file = File('test_resources/media_editor.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);
    var media = mediaRoot.media;

    expect(media.ref, '2020-10-31 14-31-09.mkv');
  });
  test('Media model can parse extra big JSON', () async {
    final file = File('test_resources/media.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);
    var media = mediaRoot.media;

    expect(media.ref, 'media-large.mkv');
  });
  test('Media model can parse H.265 2160p HDR data', () async {
    final file = File('test_resources/media-x265-2160p-HDR.json');
    Map<String, dynamic> mediaMap = jsonDecode(await file.readAsString());
    var mediaRoot = MediaRoot.fromJson(mediaMap);
    var media = mediaRoot.media;

    expect(media.ref, 'media-large.mkv');
  });
}
