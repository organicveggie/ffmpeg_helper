import 'package:built_value/built_value.dart';

part 'tv.g.dart';

abstract class TvSeries implements Built<TvSeries, TvSeriesBuilder> {
  String get name;
  String? get year;

  String? get tmdbShowId;
  String? get tvdbShowId;

  TvSeries._();
  factory TvSeries([void Function(TvSeriesBuilder) updates]) = _$TvSeries;

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

abstract class TvEpisode implements Built<TvEpisode, TvEpisodeBuilder> {
  TvSeries get series;
  String? get episodeName;
  int get episodeNumber;
  int get season;

  TvEpisode._();
  factory TvEpisode([void Function(TvEpisodeBuilder) updates]) = _$TvEpisode;

  String seasonNumber() => season.toString().padLeft(2);

  String asFullName() {
    var sb = StringBuffer(series.name);
    if (series.year != null) {
      sb.write(' (${series.year})');
    }

    var paddedEpisode = episodeNumber.toString().padLeft(2, '0');
    var paddedSeason = season.toString().padLeft(2, '0');
    sb.write(' - s${paddedSeason}e$paddedEpisode');

    if (episodeName != null) {
      sb.write(' - $episodeName');
    }

    return sb.toString();
  }
}
