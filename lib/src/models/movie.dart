import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';

part 'movie.g.dart';

abstract class MovieTitle with EquatableMixin implements Built<MovieTitle, MovieTitleBuilder> {
  MovieTitle._();
  factory MovieTitle([void Function(MovieTitleBuilder) updates]) = _$MovieTitle;

  String get name;
  String? get year;

  String? get imdbId;
  String? get tmdbId;

  @override
  List<Object?> get props => [name, year, imdbId, tmdbId];

  @override
  String toString() {
    StringBuffer b = StringBuffer(name);
    if (year != null) {
      b.write(' ($year)');
    }
    if (imdbId != null) {
      b.write(' {imdb-$imdbId}');
    }
    if (tmdbId != null) {
      b.write(' {tmdb-$tmdbId}');
    }
    return b.toString();
  }
}
