import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

void main() {
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
      }
    });
    test('returns unknown for unsupported formats', () {
      const pathnames = <String>[
        '/example/Unsupported.Format.mp3',
        '/example/Unsupported.Format.mov'
      ];
      for (var p in pathnames) {
        var got = extractMovieTitle(p);
        expect(got.name.toLowerCase(), 'unknown');
        expect(got.year, isNull);
      }
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

  group('Make movie output filename without prefix', () {
    var movie = (MovieBuilder()..name = 'My Movie').build();
    var movieWithYear = movie.rebuild((m) => m.year = '1981');
    group('without year', () {
      group('without imdb or tvdb', () {
        const tests = <Tuple3>[
          Tuple3(VideoResolution.uhd, true, '"My Movie"/"My Movie - 2160p-HDR.mkv"'),
          Tuple3(VideoResolution.uhd, false, '"My Movie"/"My Movie - 2160p.mkv"'),
          Tuple3(VideoResolution.hd, true, '"My Movie"/"My Movie - 1080p-HDR.mkv"'),
          Tuple3(VideoResolution.hd, false, '"My Movie"/"My Movie - 1080p.mkv"'),
        ];
        for (var t in tests) {
          var testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            var got = makeMovieOutputName(
                letterPrefix: false, movie: movie, targetResolution: t.item1, isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
      group('with imdb', () {
        var movieImdb = movie.rebuild((m) => m.imdbId = 'tt1234');
        const tests = <Tuple3>[
          Tuple3(VideoResolution.uhd, true,
              '"My Movie {imdb-tt1234}"/"My Movie {imdb-tt1234} - 2160p-HDR.mkv"'),
          Tuple3(VideoResolution.uhd, false,
              '"My Movie {imdb-tt1234}"/"My Movie {imdb-tt1234} - 2160p.mkv"'),
          Tuple3(VideoResolution.hd, true,
              '"My Movie {imdb-tt1234}"/"My Movie {imdb-tt1234} - 1080p-HDR.mkv"'),
          Tuple3(VideoResolution.hd, false,
              '"My Movie {imdb-tt1234}"/"My Movie {imdb-tt1234} - 1080p.mkv"'),
        ];
        for (var t in tests) {
          var testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            var got = makeMovieOutputName(
                letterPrefix: false, movie: movieImdb, targetResolution: t.item1, isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
      group('with tmdb', () {
        var movieTmdb = movie.rebuild((m) => m.tmdbId = '01234');
        const tests = <Tuple3>[
          Tuple3(VideoResolution.uhd, true,
              '"My Movie {tmdb-01234}"/"My Movie {tmdb-01234} - 2160p-HDR.mkv"'),
          Tuple3(VideoResolution.uhd, false,
              '"My Movie {tmdb-01234}"/"My Movie {tmdb-01234} - 2160p.mkv"'),
          Tuple3(VideoResolution.hd, true,
              '"My Movie {tmdb-01234}"/"My Movie {tmdb-01234} - 1080p-HDR.mkv"'),
          Tuple3(VideoResolution.hd, false,
              '"My Movie {tmdb-01234}"/"My Movie {tmdb-01234} - 1080p.mkv"'),
        ];
        for (var t in tests) {
          var testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            var got = makeMovieOutputName(
                letterPrefix: false, movie: movieTmdb, targetResolution: t.item1, isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
    });
    group('with year', () {
      group('without imdb or tvdb', () {
        const tests = <Tuple3>[
          Tuple3(VideoResolution.uhd, true, '"My Movie (1981)"/"My Movie (1981) - 2160p-HDR.mkv"'),
          Tuple3(VideoResolution.uhd, false, '"My Movie (1981)"/"My Movie (1981) - 2160p.mkv"'),
          Tuple3(VideoResolution.hd, true, '"My Movie (1981)"/"My Movie (1981) - 1080p-HDR.mkv"'),
          Tuple3(VideoResolution.hd, false, '"My Movie (1981)"/"My Movie (1981) - 1080p.mkv"'),
        ];
        for (var t in tests) {
          var testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            var got = makeMovieOutputName(
                letterPrefix: false,
                movie: movieWithYear,
                targetResolution: t.item1,
                isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
    });
  });

  group('Make movie output filename with first letter prefix', () {
    test('for UHD HDR with year', () {
      var got = makeMovieOutputName(
          letterPrefix: true,
          movie: (MovieBuilder()
                ..name = 'The First Movie'
                ..year = '1981')
              .build(),
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, 'F/"The First Movie (1981)"/"The First Movie (1981) - 2160p-HDR.mkv"');
    });
  });

  group('Make movie output filename with output folder', () {
    test('for UHD HDR with regular output folder name', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movie: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: 'my/test/folder',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, 'my/test/folder/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name', () {
      var got = makeMovieOutputName(
          letterPrefix: false,
          movie: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: '\$MOVIES',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '\$MOVIES/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name and prefix', () {
      var got = makeMovieOutputName(
          letterPrefix: true,
          movie: (MovieBuilder()..name = 'The First Movie').build(),
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

  group('make tv output filename', () {
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
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03 [1080p].mkv"');
    });
    test('1080p HDR', () {
      expect(makeTvOutputName(episode: episode, targetResolution: VideoResolution.hd, isHdr: true),
          '"Another TV Series (1986)"/season1/"Another TV Series (1986) - s01e03 [1080p HDR].mkv"');
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
