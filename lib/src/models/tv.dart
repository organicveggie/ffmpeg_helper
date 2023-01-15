import 'package:built_value/built_value.dart';
import 'package:equatable/equatable.dart';

part 'tv.g.dart';

abstract class TvSeries with EquatableMixin implements Built<TvSeries, TvSeriesBuilder> {
  String get name;
  String? get year;

  String? get tmdbShowId;
  String? get tvdbShowId;

  TvSeries._();
  factory TvSeries([void Function(TvSeriesBuilder) updates]) = _$TvSeries;

  @override
  List<Object?> get props => [name, year, tmdbShowId, tvdbShowId];

  @override
  bool get stringify => true;

  String asFullName() {
    var sb = StringBuffer(name);
    if (year != null) {
      sb.write(' ($year)');
    }
    if (tvdbShowId != null) {
      sb.write(' {tvdb-$tvdbShowId}');
    } else if (tmdbShowId != null) {
      sb.write(' {tmdb-$tmdbShowId}');
    }
    return sb.toString();
  }
}

abstract class TvEpisode with EquatableMixin implements Built<TvEpisode, TvEpisodeBuilder> {
  TvSeries get series;
  int get episodeNumber;
  int get season;

  TvEpisode._();
  factory TvEpisode([void Function(TvEpisodeBuilder) updates]) = _$TvEpisode;

  @override
  List<Object?> get props => [series, episodeNumber, season];

  @override
  bool get stringify => true;

  String seasonNumber() => season.toString().padLeft(2);

  String asFullName() {
    var sb = StringBuffer(series.name);
    if (series.year != null) {
      sb.write(' (${series.year})');
    }

    var paddedEpisode = episodeNumber.toString().padLeft(2, '0');
    var paddedSeason = season.toString().padLeft(2, '0');
    sb.write(' - s${paddedSeason}e$paddedEpisode');

    return sb.toString();
  }
}

abstract class TvOverrides implements Built<TvOverrides, TvOverridesBuilder> {
  TvOverrides._();
  factory TvOverrides([void Function(TvOverridesBuilder) updates]) = _$TvOverrides;

  String? get tmdbId;
  String? get tvdbId;
  String? get year;
}
