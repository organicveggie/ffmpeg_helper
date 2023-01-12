import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
  const VideoTrack vtH265HdHdr = VideoTrack.createFromParams(
    codecId: 'V_MPEGH/ISO/HEVC',
    format: 'HEVC',
    hdrFormat: 'SMPTE ST 2086',
    hdrFormatCompatibility: 'HDR10',
    height: 1080,
    id: '0',
    streamOrder: '0',
    uniqueId: '1',
    width: 1920,
  );

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

  const VideoTrack vtH265UhdSdr = VideoTrack.createFromParams(
    codecId: 'V_MPEGH/ISO/HEVC',
    format: 'HEVC',
    height: 2160,
    id: '1',
    streamOrder: '1',
    uniqueId: '2',
    width: 3840,
  );

  group('CapitalExtension', () {
    test('capitalizeFirstLetter', () {
      expect('soon'.capitalizeFirstLetter, 'Soon');
      expect('alphabet'.capitalizeFirstLetter, 'Alphabet');
      expect('Capitalized'.capitalizeFirstLetter, 'Capitalized');
    });

    test('capitalizeEveryWord', () {
      expect('one'.capitalizeEveryWord, 'One');
      expect('one two'.capitalizeEveryWord, 'One Two');
      expect('one two three'.capitalizeEveryWord, 'One Two Three');
      expect('name   with  extra spaces'.capitalizeEveryWord, 'Name With Extra Spaces');
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
      expect(extractMovieTitle('/example/Unsupported.Format.mp3').toString(), 'Unknown');
      expect(extractMovieTitle('/example/Unsupported.Format.mov').toString(), 'Unknown');
    });
  });

  group('Extract TV data', () {
    final unknownEpisode = (TvEpisodeBuilder()
          ..season = 1
          ..episodeNumber = 1
          ..series = (TvSeriesBuilder()..name = 'unknown'))
        .build();
    test('unknown', () {
      final got = extractTvEpisode('not-a-tv-episode.mp4');
      expect(got, unknownEpisode);
    });
    test('from period delimited', () {
      final got = extractTvEpisode('the.tv.show.S03E14.mp4');
      final want = (TvEpisodeBuilder()
            ..season = 3
            ..episodeNumber = 14
            ..series = (TvSeriesBuilder()..name = 'the tv show'))
          .build();
      expect(got, want);
    });
    test('from space delimited', () {
      final got = extractTvEpisode('the tv show  S02E03.mp4');
      final want = (TvEpisodeBuilder()
            ..season = 2
            ..episodeNumber = 3
            ..series = (TvSeriesBuilder()..name = 'the tv show'))
          .build();
      expect(got, want);
    });

    test('with extra data', () {
      final got = extractTvEpisode('The.Test.Show.S04E01.iNTERNAL.HDR.2160p.WEB.h265-SKGTV.mkv');
      final want = (TvEpisodeBuilder()
            ..season = 4
            ..episodeNumber = 1
            ..series = (TvSeriesBuilder()..name = 'The Test Show'))
          .build();
      expect(got, want);
    });
  });

  group('Make output filename without prefix', () {
    test('for UHD HDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 2160p-HDR.mkv"');
    });
    test('for UHD HDR without year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'My Movie').build(),
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '"My Movie"/"My Movie - 2160p-HDR.mkv"');
    });
    test('for UHD SDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.uhd,
          isHdr: false);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 2160p.mkv"');
    });
    test('for UHD SDR without year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'My Movie').build(),
          targetResolution: VideoResolution.uhd,
          isHdr: false);
      expect(got, '"My Movie"/"My Movie - 2160p.mkv"');
    });
    test('for HD HDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.hd,
          isHdr: true);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 1080p-HDR.mkv"');
    });
    test('for HD HDR without year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'My Movie').build(),
          targetResolution: VideoResolution.hd,
          isHdr: true);
      expect(got, '"My Movie"/"My Movie - 1080p-HDR.mkv"');
    });
    test('for HD SDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()
                ..name = 'My Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.hd,
          isHdr: false);
      expect(got, '"My Movie (1981)"/"My Movie (1981) - 1080p.mkv"');
    });
    test('for HD SDR without year', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'My Movie').build(),
          targetResolution: VideoResolution.hd,
          isHdr: false);
      expect(got, '"My Movie"/"My Movie - 1080p.mkv"');
    });
  });

  group('Make output filename with first letter prefix', () {
    test('for UHD HDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: true,
          movieTitle: (MovieBuilder()
                ..name = 'The First Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, 'F/"The First Movie (1981)"/"The First Movie (1981) - 2160p-HDR.mkv"');
    });
  });

  group('Make output filename with output folder', () {
    test('for UHD HDR with regular output folder name', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: 'my/test/folder',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, 'my/test/folder/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movieTitle: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: '\$MOVIES',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '\$MOVIES/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name and prefix', () {
      var got = makeMovieOutputName(
          letterPrefix: true,
          movieTitle: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: '\$MOVIES',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '\$MOVIES/F/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
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

  group('makeTvOutputName', () {
    final series = (TvSeriesBuilder()
          ..name = 'Another TV Series'
          ..year = '1986')
        .build();
    final episode = (TvEpisodeBuilder()
          ..series.replace(series)
          ..season = 1
          ..episodeNumber = 3)
        .build();
    test('1080p SDR', () {
      expect(makeTvOutputName(episode: episode, targetResolution: VideoResolution.hd, isHdr: false),
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03.mkv"');
    });
    test('1080p HDR', () {
      expect(makeTvOutputName(episode: episode, targetResolution: VideoResolution.hd, isHdr: true),
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03 [HDR].mkv"');
    });
    test('4k SDR', () {
      expect(
          makeTvOutputName(episode: episode, targetResolution: VideoResolution.uhd, isHdr: false),
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03 [2160p].mkv"');
    });
    test('4k HDR', () {
      expect(makeTvOutputName(episode: episode, targetResolution: VideoResolution.uhd, isHdr: true),
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03 [2160p HDR].mkv"');
    });
  });
}
