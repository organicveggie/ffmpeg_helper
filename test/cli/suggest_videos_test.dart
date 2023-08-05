import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/exceptions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

void main() {
  const VideoTrack vtH265HdSdr = VideoTrack.createFromParams(
    codecId: 'V_MPEGH/ISO/HEVC',
    format: 'HEVC',
    height: 1080,
    id: '0',
    streamOrder: '0',
    uniqueId: '1',
    width: 1920,
  );

  const VideoTrack vtH265UhdHdr = VideoTrack.createFromParams(
    codecId: 'V_MPEGH/ISO/HEVC',
    format: 'HEVC',
    hdrFormat: 'SMPTE ST 2086',
    hdrFormatCompatibility: 'HDR10',
    height: 2160,
    id: '1',
    streamOrder: '1',
    uniqueId: '2',
    width: 3840,
  );

  const VideoTrack vtH264HdSdr = VideoTrack.createFromParams(
    codecId: 'avc1',
    format: 'AVC',
    height: 1080,
    id: '2',
    streamOrder: '2',
    uniqueId: '3',
    width: 1920,
  );

  const VideoTrack vtH264UhdHdr = VideoTrack.createFromParams(
    codecId: 'avc1',
    format: 'AVC',
    hdrFormat: 'SMPTE ST 2086',
    hdrFormatCompatibility: 'HDR10',
    height: 2160,
    id: '3',
    streamOrder: '3',
    uniqueId: '4',
    width: 3840,
  );

  final defaultOptions = SuggestOptions.withDefaults(
      force: false, dpl2: false, mediaType: MediaType.movie, targetResolution: VideoResolution.uhd);

  final defaultVideoStreamConverter = (VideoStreamConvertBuilder()
        ..inputFileId = 0
        ..srcStreamId = 0
        ..dstStreamId = 0)
      .build();

  final defaultVideoStreamCopy = (StreamCopyBuilder()
        ..inputFileId = 0
        ..srcStreamId = 0
        ..dstStreamId = 0
        ..trackType = TrackType.video)
      .build();

  final scaleFilter3840 = (ScaleFilterBuilder()
        ..width = 3840
        ..height = -2)
      .build();

  group('processVideoTrack', () {
    test('throws exception for upscaling without flag', () {
      var opts = defaultOptions;
      expect(
          () => processVideoTrack(opts, vtH265HdSdr), throwsA(isA<UpscalingRequiredException>()));
    });

    test('upscales H.265 with flag', () {
      var opts = defaultOptions.rebuild((o) => o..forceUpscaling = true);
      var results = processVideoTrack(opts, vtH265HdSdr);

      expect(results, hasLength(2));
      expect(results, containsAll([scaleFilter3840, defaultVideoStreamConverter]));
    });

    test('upscales H.264 with flag', () {
      var opts = defaultOptions.rebuild((o) => o..forceUpscaling = true);
      var results = processVideoTrack(opts, vtH264HdSdr);

      expect(results, hasLength(2));
      expect(results, containsAll([scaleFilter3840, defaultVideoStreamConverter]));
    });

    test('downscaling H.265 works without flag', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.hd);
      var results = processVideoTrack(opts, vtH265UhdHdr);

      expect(results, hasLength(2));

      final scaleFilter1920 = (ScaleFilterBuilder()
            ..width = 1920
            ..height = -2)
          .build();
      expect(results, containsAll([scaleFilter1920, defaultVideoStreamConverter]));
    });

    test('H.264 UHD requires conversion to H.265 UHD with UHD target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.uhd);
      var results = processVideoTrack(opts, vtH264UhdHdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamConverter]));
    });

    test('H.264 UHD requires conversion to H.265 UHD with no video target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = null);
      var results = processVideoTrack(opts, vtH264UhdHdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamConverter]));
    });

    test('H.264 HD requires conversion to H.265 HD with HD target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.hd);
      var results = processVideoTrack(opts, vtH264HdSdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamConverter]));
    });

    test('H.264 UHD requires conversion to H.265 UHD with no video target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = null);
      var results = processVideoTrack(opts, vtH264HdSdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamConverter]));
    });

    test('Copies H.265 HD to H.265 HD with HD target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.hd);
      var results = processVideoTrack(opts, vtH265HdSdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamCopy]));
    });
    test('Copies H.265 HD to H.265 HD with no target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = null);
      var results = processVideoTrack(opts, vtH265HdSdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamCopy]));
    });

    test('Copies H.265 UHD to H.265 UHD with UHD target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.uhd);
      var results = processVideoTrack(opts, vtH265UhdHdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamCopy]));
    });

    test('Copies H.265 UHD to H.265 UHD with no target', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = null);
      var results = processVideoTrack(opts, vtH265UhdHdr);

      expect(results, hasLength(1));
      expect(results, containsAll([defaultVideoStreamCopy]));
    });
  });
}
