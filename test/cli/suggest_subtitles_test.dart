// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

void main() {
  group('Process Subtitles', () {
    test('two total, one supported', () {
      var tracks = <TextTrack>[
        TextTrack.fromMinimum(0, '0', 'eng', true, false),
        TextTrack.fromMinimum(1, '1', 'czh', false, false),
      ];
      var opts = processSubtitles(tracks.build());
      expect(opts.length, 3);
      expect(
          opts,
          containsAllInOrder([
            (StreamCopyBuilder()
                  ..trackType = TrackType.text
                  ..inputFileId = 0
                  ..srcStreamId = 0
                  ..dstStreamId = 0)
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 0
                  ..name = 'language'
                  ..value = 'eng')
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 0
                  ..name = 'handler'
                  ..value = 'English')
                .build(),
          ]));
    });
    test('three total, two supported', () {
      var tracks = <TextTrack>[
        TextTrack.fromMinimum(0, '0', 'eng', true, false),
        TextTrack.fromMinimum(1, '1', 'czh', false, false),
        const TextTrack(
            TrackType.text, 2, '2', '2', null, 'CC', 'es', false, false, 'UTF-8', 'S_TEXT/UTF8'),
      ];
      var opts = processSubtitles(tracks.build());
      expect(opts.length, 6);
      expect(
          opts,
          containsAllInOrder([
            (StreamCopyBuilder()
                  ..trackType = TrackType.text
                  ..inputFileId = 0
                  ..srcStreamId = 0
                  ..dstStreamId = 0)
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 0
                  ..name = 'language'
                  ..value = 'eng')
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 0
                  ..name = 'handler'
                  ..value = 'English')
                .build(),
            (StreamCopyBuilder()
                  ..trackType = TrackType.text
                  ..inputFileId = 0
                  ..srcStreamId = 2
                  ..dstStreamId = 1)
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 1
                  ..name = 'language'
                  ..value = 'esp')
                .build(),
            (StreamMetadataBuilder()
                  ..trackType = TrackType.text
                  ..streamId = 1
                  ..name = 'handler'
                  ..value = 'Spanish CC (SRT)')
                .build(),
          ]));
    });
  });
}
