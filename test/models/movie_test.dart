import 'package:ffmpeg_helper/src/models/movie.dart';
import 'package:test/test.dart';

void main() {
  test('asFullName', () {
    expect((MovieBuilder()..name = 'My Movie').build().asFullName(), 'My Movie');
    expect(
        (MovieBuilder()
              ..name = 'My Movie'
              ..year = '1977')
            .build()
            .asFullName(),
        'My Movie (1977)');
    expect(
        (MovieBuilder()
              ..name = 'My Movie'
              ..imdbId = '12345')
            .build()
            .asFullName(),
        'My Movie {imdb-12345}');
    expect(
        (MovieBuilder()
              ..name = 'My Movie'
              ..tmdbId = '54321')
            .build()
            .asFullName(),
        'My Movie {tmdb-54321}');
    expect(
        (MovieBuilder()
              ..name = 'My Movie'
              ..imdbId = '12345'
              ..tmdbId = '54321')
            .build()
            .asFullName(),
        'My Movie {tmdb-54321}');
  });
}
