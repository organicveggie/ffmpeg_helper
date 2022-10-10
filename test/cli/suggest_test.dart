import 'package:ffmpeg_helper/models.dart';
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

  group('Make output filename without prefix', () {
    test('for UHD HDR with year', () {
      var got = makeOutputName(
          false,
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265UhdHdr);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 2160p-HDR.mkv"');
    });
    test('for UHD HDR without year', () {
      var got =
          makeOutputName(false, (MovieTitleBuilder()..name = 'My Movie').build(), vtH265UhdHdr);
      expect(got, '"My Movie"/"My Movie - 2160p-HDR.mkv"');
    });
    test('for UHD SDR with year', () {
      var got = makeOutputName(
          false,
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265UhdSdr);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 2160p.mkv"');
    });
    test('for UHD SDR without year', () {
      var got =
          makeOutputName(false, (MovieTitleBuilder()..name = 'My Movie').build(), vtH265UhdSdr);
      expect(got, '"My Movie"/"My Movie - 2160p.mkv"');
    });
    test('for HD HDR with year', () {
      var got = makeOutputName(
          false,
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265HdHdr);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 1080p-HDR.mkv"');
    });
    test('for HD HDR without year', () {
      var got =
          makeOutputName(false, (MovieTitleBuilder()..name = 'My Movie').build(), vtH265HdHdr);
      expect(got, '"My Movie"/"My Movie - 1080p-HDR.mkv"');
    });
    test('for HD SDR with year', () {
      var got = makeOutputName(
          false,
          (MovieTitleBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          vtH265HdSdr);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 1080p.mkv"');
    });
    test('for HD SDR without year', () {
      var got =
          makeOutputName(false, (MovieTitleBuilder()..name = 'My Movie').build(), vtH265HdSdr);
      expect(got, '"My Movie"/"My Movie - 1080p.mkv"');
    });
  });

  group('Make output filename with prefix', () {
    test('for UHD HDR with year', () {
      var got = makeOutputName(
          true,
          (MovieTitleBuilder()
                ..name = 'The First Movie'
                ..year = '1981')
              .build(),
          vtH265UhdHdr);
      expect(got, 'F/"The First Movie (1981)"/"The First Movie (1981) - 2160p-HDR.mkv"');
    });
  });

  group('Get first letter of movie title', () {
    const tests = <Tuple3<String, String, String>>[
      Tuple3('no stop words', 'Boogie Nights', 'B'),
      Tuple3('ignores "the"', 'The Big Lebowski', 'B'),
      Tuple3('ignores "a"', 'A Fish Called Wanda', 'F'),
      Tuple3('ignores "an"', 'An American Werewolf in London (1981)', 'A'),
      Tuple3('number as range', '12 Years a Slave (2013)', '0-9'),
    ];
    for (var t in tests) {
      test(t.item1, () {
        expect(getMovieTitleFirstLetter(t.item2), t.item3);
      });
    }
  });
}
