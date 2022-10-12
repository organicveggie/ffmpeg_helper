import 'package:ffmpeg_helper/src/models/tv.dart';
import 'package:test/test.dart';

void main() {
  group(TvSeries, () {
    group('asFullName', () {
      test('name and year', () {
        expect((TvSeriesBuilder()..name = 'My TV Series').build().asFullName(), 'My TV Series');
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..year = '1977')
                .build()
                .asFullName(),
            'My TV Series (1977)');
      });
      test('tmdb', () {
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..tmdbShowId = '1234')
                .build()
                .asFullName(),
            'My TV Series {tmdb-1234}');
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..year = '1977'
                  ..tmdbShowId = '1234')
                .build()
                .asFullName(),
            'My TV Series (1977) {tmdb-1234}');
      });
      test('tvdb', () {
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..tvdbShowId = '5678')
                .build()
                .asFullName(),
            'My TV Series {tvdb-5678}');
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..year = '1977'
                  ..tvdbShowId = '5678')
                .build()
                .asFullName(),
            'My TV Series (1977) {tvdb-5678}');
      });
      test('asFullName prefers tvdb over tmdb', () {
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..tvdbShowId = '5678'
                  ..tmdbShowId = '1234')
                .build()
                .asFullName(),
            'My TV Series {tvdb-5678}');
        expect(
            (TvSeriesBuilder()
                  ..name = 'My TV Series'
                  ..year = '1977'
                  ..tvdbShowId = '5678'
                  ..tmdbShowId = '1234')
                .build()
                .asFullName(),
            'My TV Series (1977) {tvdb-5678}');
      });
    });
  });

  group(TvEpisode, () {
    final series = (TvSeriesBuilder()..name = 'My TV Series').build();
    final seriesYear = (TvSeriesBuilder()
          ..name = 'My TV Series'
          ..year = '1977')
        .build();
    test('asFullName', () {
      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 3
                ..season = 1)
              .build()
              .asFullName(),
          'My TV Series - s01e03');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 3
                ..season = 1)
              .build()
              .asFullName(),
          'My TV Series (1977) - s01e03');

      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 3
                ..season = 10)
              .build()
              .asFullName(),
          'My TV Series - s10e03');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 13
                ..season = 1)
              .build()
              .asFullName(),
          'My TV Series (1977) - s01e13');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 13
                ..season = 10)
              .build()
              .asFullName(),
          'My TV Series (1977) - s10e13');
    });

    test('asFullName with episode name', () {
      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 3
                ..season = 1
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series - s01e03 - Test Episode');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 3
                ..season = 1
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series (1977) - s01e03 - Test Episode');

      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 3
                ..season = 10
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series - s10e03 - Test Episode');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 3
                ..season = 10
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series (1977) - s10e03 - Test Episode');

      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 13
                ..season = 1
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series - s01e13 - Test Episode');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 13
                ..season = 1
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series (1977) - s01e13 - Test Episode');

      expect(
          (TvEpisodeBuilder()
                ..series.replace(series)
                ..episodeNumber = 13
                ..season = 11
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series - s11e13 - Test Episode');
      expect(
          (TvEpisodeBuilder()
                ..series.replace(seriesYear)
                ..episodeNumber = 13
                ..season = 11
                ..episodeName = 'Test Episode')
              .build()
              .asFullName(),
          'My TV Series (1977) - s11e13 - Test Episode');
    });
  });
}
