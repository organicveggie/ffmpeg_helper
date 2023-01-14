import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';

part 'movie.g.dart';

abstract class Movie with EquatableMixin implements Built<Movie, MovieBuilder> {
  Movie._();
  factory Movie([void Function(MovieBuilder) updates]) = _$Movie;

  String get name;
  String? get year;

  String? get imdbId;
  String? get tmdbId;

  @override
  List<Object?> get props => [name, year, imdbId, tmdbId];

  String asFullName() {
    StringBuffer b = StringBuffer(name);
    if (year != null) {
      b.write(' ($year)');
    }

    // Prefer TMDB over IMDB.
    if (tmdbId != null) {
      b.write(' {tmdb-$tmdbId}');
    } else if (imdbId != null) {
      b.write(' {imdb-$imdbId}');
    }
    return b.toString();
  }
}
