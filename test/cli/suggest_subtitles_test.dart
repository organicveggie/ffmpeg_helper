// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

void main() {
  group('Process Subtitles', () {
    test('two total, one supported', () {
      const tracks = <TextTrack>[
        TextTrack.fromParams(typeOrder: 0, id: '0', language: 'eng', isDefault: true),
        TextTrack.fromParams(typeOrder: 1, id: '1', language: 'czh'),
      ];
      final opts = processSubtitles(tracks.build());
      expect(opts.length, 3);
      expect(
          opts,
          containsAllInOrder([
            StreamCopy((b) => b
              ..trackType = TrackType.text
              ..inputFileId = 0
              ..srcStreamId = 0
              ..dstStreamId = 0),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 0
              ..name = 'language'
              ..value = 'eng'),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 0
              ..name = 'handler'
              ..value = 'English'),
          ]));
    });
    test('three total, two supported', () {
      const tracks = <TextTrack>[
        TextTrack.fromParams(typeOrder: 0, id: '0', language: 'eng', isDefault: true),
        TextTrack.fromParams(typeOrder: 1, id: '1', language: 'czh'),
        TextTrack.fromParams(
            typeOrder: 2,
            id: '2',
            uniqueId: '2',
            title: 'CC',
            language: 'es',
            format: 'UTF-8',
            codecId: 'S_TEXT/UTF8'),
      ];
      var opts = processSubtitles(tracks.build());
      expect(opts.length, 6);
      expect(
          opts,
          containsAllInOrder([
            StreamCopy((b) => b
              ..trackType = TrackType.text
              ..inputFileId = 0
              ..srcStreamId = 0
              ..dstStreamId = 0),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 0
              ..name = 'language'
              ..value = 'eng'),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 0
              ..name = 'handler'
              ..value = 'English'),
            StreamCopy((b) => b
              ..trackType = TrackType.text
              ..inputFileId = 0
              ..srcStreamId = 2
              ..dstStreamId = 1),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 1
              ..name = 'language'
              ..value = 'esp'),
            StreamMetadata((b) => b
              ..trackType = TrackType.text
              ..streamId = 1
              ..name = 'handler'
              ..value = 'Spanish CC (SRT)'),
          ]));
    });
  });
}
