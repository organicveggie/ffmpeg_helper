import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;

import 'exceptions.dart';

part 'suggest.g.dart';

enum MediaType {
  movie,
  tv;

  static Iterable<String> names() => MediaType.values.map((v) => v.name);
}

enum VideoResolution {
  hd(['1080', '1080p']),
  uhd(['4k', '2160', '2160p']);

  final List<String> aliases;

  const VideoResolution(this.aliases);

  static Iterable<String> names() => VideoResolution.values.map((v) => v.name);
  static Iterable<String> allNames() {
    var all = <String>[];
    for (var v in VideoResolution.values) {
      all.add(v.name);
      all.addAll(v.aliases);
    }
    all.sort();
    return all;
  }
}

abstract class SuggestOptions implements Built<SuggestOptions, SuggestOptionsBuilder> {
  MediaType get mediaType;

  SuggestOptions._();
  factory SuggestOptions([void Function(SuggestOptionsBuilder) updates]) = _$SuggestOptions;
}

abstract class AudioFinder implements Built<AudioFinder, AudioFinderBuilder> {
  AudioFinder._();
  factory AudioFinder([void Function(AudioFinderBuilder) updates]) = _$AudioFinder;

  BuiltMap<AudioFormat, wrappers.AudioTrack> get tracksByFormat;

  /// Finds the best source audio track for outputting E-AC3 (Dolby Digital or Dolby Digital Plus).
  wrappers.AudioTrack bestForEAC3() {
    // Prefer DD+ or DD, since we can just copy them.
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }

    // If we have multi-channel AAC, but no lossless formats or DTS, then use the multi-channel AAC.
    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      // If no lossless or DTS formats present, then multi-channel AAC is the best we have.
      if (!tracksByFormat.containsKey(AudioFormat.trueHD) &&
          !tracksByFormat.containsKey(AudioFormat.dtsHDMA) &&
          !tracksByFormat.containsKey(AudioFormat.dtsX) &&
          !tracksByFormat.containsKey(AudioFormat.dts)) {
        return tracksByFormat[AudioFormat.aacMulti]!;
      }
    }

    // If we have lossless formats, choose one of those.
    if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
      return tracksByFormat[AudioFormat.trueHD]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
      return tracksByFormat[AudioFormat.dtsHDMA]!;
    }

    // Next best are DTS formats.
    if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
      return tracksByFormat[AudioFormat.dtsX]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dts)) {
      return tracksByFormat[AudioFormat.dts]!;
    }

    // Stereo and mono as fallbacks
    if (tracksByFormat.containsKey(AudioFormat.stereo)) {
      return tracksByFormat[AudioFormat.stereo]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.mono)) {
      return tracksByFormat[AudioFormat.mono]!;
    }

    throw MissingAudioSourceException('primary multichannel', tracksByFormat.keys.toList());
  }

  /// Finds the best source audio track for multi-channel AAC output.
  wrappers.AudioTrack bestForMultiChannelAAC() {
    // Use existing multi-channel AAC track, if it exists.
    // TODO: check bitrates
    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      return tracksByFormat[AudioFormat.aacMulti]!;
    }

    // If we have lossless formats, choose one of those.
    if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
      return tracksByFormat[AudioFormat.trueHD]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
      return tracksByFormat[AudioFormat.dtsHDMA]!;
    }

    // If we have lossy multi-channel formats, use one of them.
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
      return tracksByFormat[AudioFormat.dtsX]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dts)) {
      return tracksByFormat[AudioFormat.dts]!;
    }

    // Stereo and mono as fallbacks
    if (tracksByFormat.containsKey(AudioFormat.stereo)) {
      return tracksByFormat[AudioFormat.stereo]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.mono)) {
      return tracksByFormat[AudioFormat.mono]!;
    }

    throw MissingAudioSourceException('AAC multichannel', tracksByFormat.keys.toList());
  }

  wrappers.AudioTrack bestForDolbyProLogic2() {
    // If we have lossless formats, choose one of those.
    if (tracksByFormat.containsKey(AudioFormat.trueHD)) {
      return tracksByFormat[AudioFormat.trueHD]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsHDMA)) {
      return tracksByFormat[AudioFormat.dtsHDMA]!;
    }

    // If we have lossy multi-channel formats, use one of them.
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigitalPlus)) {
      return tracksByFormat[AudioFormat.dolbyDigitalPlus]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dolbyDigital)) {
      return tracksByFormat[AudioFormat.dolbyDigital]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dtsX)) {
      return tracksByFormat[AudioFormat.dtsX]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.dts)) {
      return tracksByFormat[AudioFormat.dts]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.aacMulti)) {
      return tracksByFormat[AudioFormat.aacMulti]!;
    }

    // Stereo and mono as fallbacks
    if (tracksByFormat.containsKey(AudioFormat.stereo)) {
      return tracksByFormat[AudioFormat.stereo]!;
    }
    if (tracksByFormat.containsKey(AudioFormat.mono)) {
      return tracksByFormat[AudioFormat.mono]!;
    }

    throw MissingAudioSourceException('Dolby Pro Logic II', tracksByFormat.keys.toList());
  }
}
