import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;

import 'enums.dart';
import 'exceptions.dart';

part 'audio_finder.g.dart';

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
