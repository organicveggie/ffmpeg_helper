import 'package:built_collection/built_collection.dart';
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

  group('Extract movie data from filename', () {
    group('without overrides', () {
      final overrides = MovieOverrides();
      test('from full pathname with periods but without year', () {
        const pathnames = <String>[
          '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
          '/home/user/example/My.Fake.Movie.1080p-SDR.mp4',
          '/home/user/example/My.Fake.Movie.1080p-SDR.m4v',
        ];
        for (final p in pathnames) {
          final got = extractMovieTitle(p, overrides);
          expect(got.imdbId, isNull);
          expect(got.name, 'My Fake Movie');
          expect(got.tmdbId, isNull);
          expect(got.year, isNull);
        }
      });
      test('from full pathname with year and periods', () {
        const pathnames = <Tuple3<String, String, String>>[
          Tuple3('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', 'My Fake Movie', '1977'),
          Tuple3('/home/user/example/My.Fake.Movie.1978.1080p-SDR.mkv', 'My Fake Movie', '1978'),
          Tuple3('/home/user/example/My.Fake.Movie.1979.1080p-SDR.mkv', 'My Fake Movie', '1979'),
        ];
        for (final p in pathnames) {
          final got = extractMovieTitle(p.item1, overrides);
          expect(got.imdbId, isNull);
          expect(got.name, p.item2);
          expect(got.tmdbId, isNull);
          expect(got.year, p.item3);
        }
      });
      test('returns unknown for unsupported formats', () {
        const pathnames = <String>[
          '/example/Unsupported.Format.mp3',
          '/example/Unsupported.Format.mov'
        ];
        for (final p in pathnames) {
          final got = extractMovieTitle(p, overrides);
          expect(got.imdbId, isNull);
          expect(got.name.toLowerCase(), 'unknown');
          expect(got.tmdbId, isNull);
          expect(got.year, isNull);
        }
      });
    });
    group('with overrides', () {
      group('for imdb', () {
        final overrides = MovieOverrides((b) => b..imdbId = 'tt1234');
        test('from full pathname with periods but without year', () {
          const pathnames = <String>[
            '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
            '/home/user/example/My.Fake.Movie.1080p-SDR.mp4',
            '/home/user/example/My.Fake.Movie.1080p-SDR.m4v',
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p, overrides);
            expect(got.imdbId, overrides.imdbId);
            expect(got.name, 'My Fake Movie');
            expect(got.tmdbId, isNull);
            expect(got.year, isNull);
          }
        });
        test('from full pathname with year and periods', () {
          const pathnames = <Tuple3<String, String, String>>[
            Tuple3('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', 'My Fake Movie', '1977'),
            Tuple3('/home/user/example/My.Fake.Movie.1978.1080p-SDR.mkv', 'My Fake Movie', '1978'),
            Tuple3('/home/user/example/My.Fake.Movie.1979.1080p-SDR.mkv', 'My Fake Movie', '1979'),
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p.item1, overrides);
            expect(got.imdbId, overrides.imdbId);
            expect(got.name, p.item2);
            expect(got.tmdbId, isNull);
            expect(got.year, p.item3);
          }
        });
      });
      group('for tmdb', () {
        final overrides = MovieOverrides((b) => b..tmdbId = '01234');
        test('from full pathname with periods but without year', () {
          const pathnames = <String>[
            '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
            '/home/user/example/My.Fake.Movie.1080p-SDR.mp4',
            '/home/user/example/My.Fake.Movie.1080p-SDR.m4v',
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, 'My Fake Movie');
            expect(got.tmdbId, overrides.tmdbId);
            expect(got.year, isNull);
          }
        });
        test('from full pathname with year and periods', () {
          const pathnames = <Tuple3<String, String, String>>[
            Tuple3('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', 'My Fake Movie', '1977'),
            Tuple3('/home/user/example/My.Fake.Movie.1978.1080p-SDR.mkv', 'My Fake Movie', '1978'),
            Tuple3('/home/user/example/My.Fake.Movie.1979.1080p-SDR.mkv', 'My Fake Movie', '1979'),
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p.item1, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, p.item2);
            expect(got.tmdbId, overrides.tmdbId);
            expect(got.year, p.item3);
          }
        });
      });
      group('for year', () {
        final overrides = MovieOverrides((b) => b..year = '1977');
        test('from full pathname with periods but without year', () {
          const pathnames = <String>[
            '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
            '/home/user/example/My.Fake.Movie.1080p-SDR.mp4',
            '/home/user/example/My.Fake.Movie.1080p-SDR.m4v',
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, 'My Fake Movie');
            expect(got.tmdbId, isNull);
            expect(got.year, '1977');
          }
        });
        test('from full pathname with year and periods', () {
          const pathnames = <Tuple2<String, String>>[
            Tuple2('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', 'My Fake Movie'),
            Tuple2('/home/user/example/My.Fake.Movie.1978.1080p-SDR.mkv', 'My Fake Movie'),
            Tuple2('/home/user/example/My.Fake.Movie.1979.1080p-SDR.mkv', 'My Fake Movie'),
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p.item1, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, p.item2);
            expect(got.tmdbId, isNull);
            expect(got.year, '1977');
          }
        });
      });
      group('for name', () {
        final overrides = MovieOverrides((b) => b..name = 'A Different Fake Movie');
        test('from full pathname with periods but without year', () {
          const pathnames = <String>[
            '/home/user/example/My.Fake.Movie.1080p-SDR.mkv',
            '/home/user/example/My.Fake.Movie.2160p-HDR.mp4',
            '/home/user/example/My.Fake.Movie.m4v',
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, 'A Different Fake Movie');
            expect(got.tmdbId, isNull);
            expect(got.year, isNull);
          }
        });
        test('from full pathname with year and periods', () {
          const pathnames = <Tuple2<String, String>>[
            Tuple2('/home/user/example/My.Fake.Movie.1977.1080p-SDR.mkv', '1977'),
            Tuple2('/home/user/example/My.Fake.Movie.1978.HDR.mkv', '1978'),
            Tuple2('/home/user/example/My.Fake.Movie.1979.2160p.mkv', '1979'),
          ];
          for (final p in pathnames) {
            final got = extractMovieTitle(p.item1, overrides);
            expect(got.imdbId, isNull);
            expect(got.name, 'A Different Fake Movie');
            expect(got.tmdbId, isNull);
            expect(got.year, p.item2);
          }
        });
      });
    });
  });

  group('Extract TV data', () {
    final unknownEpisode = TvEpisode((b) => b
      ..season = 1
      ..episodeNumber = 1
      ..series = (TvSeriesBuilder()..name = 'unknown'));
    final overrides = TvOverrides();
    test('unknown', () {
      final got = extractTvEpisode('not-a-tv-episode.mp4', overrides);
      expect(got, unknownEpisode);
    });
    test('from period delimited', () {
      final got = extractTvEpisode('the.tv.show.S03E14.mp4', overrides);
      final want = TvEpisode((b) => b
        ..season = 3
        ..episodeNumber = 14
        ..series = (TvSeriesBuilder()..name = 'the tv show'));
      expect(got, want);
    });
    test('from space delimited', () {
      final got = extractTvEpisode('the tv show  S02E03.mp4', overrides);
      final want = TvEpisode((b) => b
        ..season = 2
        ..episodeNumber = 3
        ..series = (TvSeriesBuilder()..name = 'the tv show'));
      expect(got, want);
    });

    test('with extra data', () {
      final got =
          extractTvEpisode('The.Test.Show.S04E01.iNTERNAL.HDR.2160p.WEB.h265-SKGTV.mkv', overrides);
      final want = TvEpisode((b) => b
        ..season = 4
        ..episodeNumber = 1
        ..series = (TvSeriesBuilder()..name = 'The Test Show'));
      expect(got, want);
    });
  });

  group('Make movie output filename without prefix', () {
    final movie = Movie((b) => b..name = 'My Movie');
    final movieWithYear = movie.rebuild((m) => m.year = '1981');
    group('without year', () {
      group('without imdb or tvdb', () {
        const tests = <Tuple3>[
          Tuple3(VideoResolution.uhd, true, '"My Movie"/"My Movie - 2160p-HDR.mkv"'),
          Tuple3(VideoResolution.uhd, false, '"My Movie"/"My Movie - 2160p.mkv"'),
          Tuple3(VideoResolution.hd, true, '"My Movie"/"My Movie - 1080p-HDR.mkv"'),
          Tuple3(VideoResolution.hd, false, '"My Movie"/"My Movie - 1080p.mkv"'),
        ];
        for (final t in tests) {
          final testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            final got = makeMovieOutputName(
                letterPrefix: false, movie: movie, targetResolution: t.item1, isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
      group('with imdb', () {
        final movieImdb = movie.rebuild((m) => m.imdbId = 'tt1234');
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
        for (final t in tests) {
          final testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            final got = makeMovieOutputName(
                letterPrefix: false, movie: movieImdb, targetResolution: t.item1, isHdr: t.item2);
            expect(got, t.item3);
          });
        }
      });
      group('with tmdb', () {
        final movieTmdb = movie.rebuild((m) => m.tmdbId = '01234');
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
        for (final t in tests) {
          final testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            final got = makeMovieOutputName(
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
        for (final t in tests) {
          final testName = '${t.item1.toString()} ${t.item2 ? "HDR" : "SDR"}';
          test(testName, () {
            final got = makeMovieOutputName(
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
      final got = makeMovieOutputName(
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
      final got = makeMovieOutputName(
          letterPrefix: false,
          movie: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: 'my/test/folder',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, 'my/test/folder/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name', () {
      final got = makeMovieOutputName(
          letterPrefix: false,
          movie: (MovieBuilder()..name = 'The First Movie').build(),
          outputFolder: '\$MOVIES',
          targetResolution: VideoResolution.uhd,
          isHdr: true);
      expect(got, '\$MOVIES/"The First Movie"/"The First Movie - 2160p-HDR.mkv"');
    });
    test('for UHD HDR with Bash variable output folder name and prefix', () {
      final got = makeMovieOutputName(
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
    for (final t in tests) {
      test(t.item1, () {
        expect(getMovieTitleFirstLetter(t.item2), t.item3);
      });
    }
  });

  group('make tv output filename', () {
    final series = TvSeries((b) => b
      ..name = 'Another TV Series'
      ..year = '1986');
    final episode = TvEpisode((b) => b
      ..series.replace(series)
      ..season = 1
      ..episodeNumber = 3);
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

  group('filter tracks', () {
    test('excludes commentary tracks', () {
      final tracks = BuiltList<AudioTrack>.of([
        AudioTrack.fromParams(
            id: '0',
            codecId: AudioFormat.dolbyDigitalPlus.codecId,
            format: AudioFormat.dolbyDigitalPlus.format,
            streamOrder: '1',
            typeOrder: 0),
        AudioTrack.fromParams(
            id: '1',
            codecId: AudioFormat.dts.codecId,
            format: AudioFormat.dts.format,
            streamOrder: '2',
            typeOrder: 1),
        AudioTrack.fromParams(
            id: '2',
            codecId: AudioFormat.stereo.codecId,
            format: AudioFormat.stereo.format,
            streamOrder: '3',
            typeOrder: 2,
            title: 'Director\'s commentary'),
        AudioTrack.fromParams(
            id: '3',
            codecId: AudioFormat.stereo.codecId,
            format: AudioFormat.stereo.format,
            streamOrder: '4',
            typeOrder: 3,
            title: 'Actor Commentary'),
      ]);
      final filteredTracks = filterTracks(tracks: tracks);
      expect(filteredTracks.length, equals(2));
    });

    test('ignores null language code', () {
      final tracks = BuiltList<AudioTrack>.of([
        AudioTrack.fromParams(
            id: '0',
            codecId: AudioFormat.dolbyDigitalPlus.codecId,
            format: AudioFormat.dolbyDigitalPlus.format,
            streamOrder: '1',
            typeOrder: 0),
        AudioTrack.fromParams(
            id: '1',
            codecId: AudioFormat.dts.codecId,
            format: AudioFormat.dts.format,
            streamOrder: '2',
            typeOrder: 1,
            language: Language.german.iso)
      ]);
      final filteredTracks = filterTracks(tracks: tracks);
      expect(filteredTracks.length, equals(2));
    });

    test('filters by language', () {
      final tracks = BuiltList<AudioTrack>.of([
        AudioTrack.fromParams(
            id: '0',
            codecId: AudioFormat.dolbyDigitalPlus.codecId,
            format: AudioFormat.dolbyDigitalPlus.format,
            streamOrder: '1',
            typeOrder: 0,
            language: Language.english.iso),
        AudioTrack.fromParams(
            id: '1',
            codecId: AudioFormat.dts.codecId,
            format: AudioFormat.dts.format,
            streamOrder: '2',
            typeOrder: 1,
            language: Language.german.iso)
      ]);
      final filteredTracks = filterTracks(tracks: tracks, language: Language.german);
      expect(filteredTracks.length, equals(1));
    });

    test('does not filter tracks without language', () {
      final tracks = BuiltList<AudioTrack>.of([
        AudioTrack.fromParams(
            id: '0',
            codecId: AudioFormat.dolbyDigitalPlus.codecId,
            format: AudioFormat.dolbyDigitalPlus.format,
            streamOrder: '1',
            typeOrder: 0),
        AudioTrack.fromParams(
            id: '1',
            codecId: AudioFormat.dts.codecId,
            format: AudioFormat.dts.format,
            streamOrder: '2',
            typeOrder: 1,
            language: Language.german.iso)
      ]);
      final filteredTracks = filterTracks(tracks: tracks, language: Language.german);
      expect(filteredTracks.length, equals(2));
    });
  });
}
