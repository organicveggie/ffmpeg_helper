import 'package:ffmpeg_helper/src/models/tv.dart';
import 'package:test/test.dart';

void main() {
  group(TvSeries, () {
    group('asFullName', () {
      test('name and year', () {
        expect(TvSeries((b) => b..name = 'My TV Series').asFullName(), 'My TV Series');
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..year = '1977').asFullName(),
            'My TV Series (1977)');
      });
      test('tmdb', () {
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..tmdbShowId = '1234').asFullName(),
            'My TV Series {tmdb-1234}');
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..year = '1977'
              ..tmdbShowId = '1234').asFullName(),
            'My TV Series (1977) {tmdb-1234}');
      });
      test('tvdb', () {
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..tvdbShowId = '5678').asFullName(),
            'My TV Series {tvdb-5678}');
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..year = '1977'
              ..tvdbShowId = '5678').asFullName(),
            'My TV Series (1977) {tvdb-5678}');
      });
      test('asFullName prefers tvdb over tmdb', () {
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..tvdbShowId = '5678'
              ..tmdbShowId = '1234').asFullName(),
            'My TV Series {tvdb-5678}');
        expect(
            TvSeries((b) => b
              ..name = 'My TV Series'
              ..year = '1977'
              ..tvdbShowId = '5678'
              ..tmdbShowId = '1234').asFullName(),
            'My TV Series (1977) {tvdb-5678}');
      });
    });
  });

  group(TvEpisode, () {
    final series = TvSeries((b) => b..name = 'My TV Series');
    final seriesYear = TvSeries((b) => b
      ..name = 'My TV Series'
      ..year = '1977');
    test('asFullName', () {
      expect(
          TvEpisode((b) => b
            ..series.replace(series)
            ..episodeNumber = 3
            ..season = 1).asFullName(),
          'My TV Series - s01e03');
      expect(
          TvEpisode((b) => b
            ..series.replace(series)
            ..episodeNumber = 3
            ..season = 10).asFullName(),
          'My TV Series - s10e03');
      expect(
          TvEpisode((b) => b
            ..series.replace(seriesYear)
            ..episodeNumber = 3
            ..season = 1).asFullName(),
          'My TV Series (1977) - s01e03');
      expect(
          TvEpisode((b) => b
            ..series.replace(seriesYear)
            ..episodeNumber = 13
            ..season = 1).asFullName(),
          'My TV Series (1977) - s01e13');
      expect(
          TvEpisode((b) => b
            ..series.replace(seriesYear)
            ..episodeNumber = 13
            ..season = 10).asFullName(),
          'My TV Series (1977) - s10e13');
    });
  });
}
