import 'package:ffmpeg_helper/src/models/movie.dart';
import 'package:test/test.dart';

void main() {
  test('asFullName', () {
    expect(Movie((b) => b..name = 'My Movie').asFullName(), 'My Movie');
    expect(
        Movie((b) => b
          ..name = 'My Movie'
          ..year = '1977').asFullName(),
        'My Movie (1977)');
    expect(
        Movie((b) => b
          ..name = 'My Movie'
          ..imdbId = '12345').asFullName(),
        'My Movie {imdb-12345}');
    expect(
        Movie((b) => b
          ..name = 'My Movie'
          ..tmdbId = '54321').asFullName(),
        'My Movie {tmdb-54321}');
    expect(
        Movie((b) => b
          ..name = 'My Movie'
          ..imdbId = '12345'
          ..tmdbId = '54321').asFullName(),
        'My Movie {tmdb-54321}');
  });
}
