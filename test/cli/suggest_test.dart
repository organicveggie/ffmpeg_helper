import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/exceptions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  const VideoTrack vtH265HdHdr = VideoTrack.create(
      '0', 'V_MPEGH/ISO/HEVC', '1', '0', null, 'HEVC', 1920, 1080, 'SMPTE ST 2086', 'HDR10');

  const VideoTrack vtH265HdSdr =
      VideoTrack.create('0', 'V_MPEGH/ISO/HEVC', '1', '0', null, 'HEVC', 1920, 1080, null, null);

  const VideoTrack vtH265UhdHdr = VideoTrack.create(
      '1', 'V_MPEGH/ISO/HEVC', '2', '1', null, 'HEVC', 3840, 2160, 'SMPTE ST 2086', 'HDR10');

  const VideoTrack vtH265UhdSdr =
      VideoTrack.create('1', 'V_MPEGH/ISO/HEVC', '2', '1', null, 'HEVC', 3840, 2160, null, null);

  const VideoTrack vtH264HdSdr =
      VideoTrack.create('2', 'avc1', '3', '2', null, 'AVC', 1920, 1080, null, null);

  const VideoTrack vtH264UhdHdr =
      VideoTrack.create('3', 'avc1', '4', '3', null, 'AVC', 3840, 2160, null, null);

  final defaultOptions = (SuggestOptionsBuilder()
        ..forceUpscaling = false
        ..generateDPL2 = false
        ..mediaType = MediaType.movie
        ..targetResolution = VideoResolution.uhd)
      .build();

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

  final scaleFilter1920 = (ScaleFilterBuilder()
        ..width = 1920
        ..height = -1)
      .build();
  final scaleFilter3840 = (ScaleFilterBuilder()
        ..width = 3840
        ..height = -1)
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
      expect(results, containsAll([scaleFilter1920, defaultVideoStreamConverter]));
    });

    test('downscaling H.264 works without force flag', () {
      var opts = defaultOptions.rebuild((o) => o..targetResolution = VideoResolution.hd);
      var results = processVideoTrack(opts, vtH264UhdHdr);

      expect(results, hasLength(2));
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

  group('Extract movie title', () {
    test('from full pathname with periods but without year', () {
      var pathnames = <String>[
        '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
        '/home/user/example/My.Fake.Movie.1080p-SDR.mp4',
        '/home/user/example/My.Fake.Movie.1080p-SDR.m4v',
      ];
      for (var p in pathnames) {
        var got = extractMovieTitle(p);
        expect(got.name, 'My Fake Movie');
        expect(got.year, isNull);
        expect(got.toString(), 'My Fake Movie');
      }
    });
    test('from full pathname with year and periods', () {
      const pathnames = <Tuple3<String, String, String>>[
        Tuple3('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', 'My Fake Movie', '1977'),
        Tuple3('/home/user/example/My.Fake.Movie.1978.1080p-SDR.mkv', 'My Fake Movie', '1978'),
        Tuple3('/home/user/example/My.Fake.Movie.1979.1080p-SDR.mkv', 'My Fake Movie', '1979'),
      ];
      for (var p in pathnames) {
        var got = extractMovieTitle(p.item1);
        expect(got.name, p.item2);
        expect(got.year, p.item3);
        expect(got.toString(), '${p.item2} (${p.item3})');
      }
    });
    test('returns unknown for unsupported formats', () {
      expect(extractMovieTitle('/example/Unsupported.Format.mp3').toString(), 'unknown');
      expect(extractMovieTitle('/example/Unsupported.Format.mov').toString(), 'unknown');
    });
  });

  group('Make output filename', () {
    test('for UHD HDR with year', () {
      var got = makeOutputName(
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265UhdHdr);
      expect(got, 'My Movie (1981)/My Movie (1981) - 2160p - HDR.mkv');
    });
    test('for UHD HDR without year', () {
      var got = makeOutputName((MovieTitleBuilder()..name = 'My Movie').build(), vtH265UhdHdr);
      expect(got, 'My Movie/My Movie - 2160p - HDR.mkv');
    });
    test('for UHD SDR with year', () {
      var got = makeOutputName(
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265UhdSdr);
      expect(got, 'My Movie (1981)/My Movie (1981) - 2160p.mkv');
    });
    test('for UHD SDR without year', () {
      var got = makeOutputName((MovieTitleBuilder()..name = 'My Movie').build(), vtH265UhdSdr);
      expect(got, 'My Movie/My Movie - 2160p.mkv');
    });
    test('for HD HDR with year', () {
      var got = makeOutputName(
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265HdHdr);
      expect(got, 'My Movie (1981)/My Movie (1981) - 1080p - HDR.mkv');
    });
    test('for HD HDR without year', () {
      var got = makeOutputName((MovieTitleBuilder()..name = 'My Movie').build(), vtH265HdHdr);
      expect(got, 'My Movie/My Movie - 1080p - HDR.mkv');
    });
    test('for HD SDR with year', () {
      var got = makeOutputName(
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265HdSdr);
      expect(got, 'My Movie (1981)/My Movie (1981) - 1080p.mkv');
    });
    test('for HD SDR without year', () {
      var got = makeOutputName((MovieTitleBuilder()..name = 'My Movie').build(), vtH265HdSdr);
      expect(got, 'My Movie/My Movie - 1080p.mkv');
    });
  });
}
