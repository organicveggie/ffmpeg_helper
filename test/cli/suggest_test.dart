import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

class SuggestTest {
  final String name;
  final BuiltMap<AudioFormat, wrappers.AudioTrack> trackMap;
  final AudioFormat expectedFormat;

  SuggestTest(this.name, this.expectedFormat, this.trackMap);

  factory SuggestTest.fromTracks(
      {required String name,
      required AudioFormat expected,
      required BuiltList<AudioTrack> tracks}) {
    var trackMap = <AudioFormat, wrappers.AudioTrack>{};
    tracks.forEachIndexed((i, t) {
      trackMap[t.toAudioFormat()] = wrappers.AudioTrack(i, t);
    });

    return SuggestTest(name, expected, trackMap.build());
  }
}

void main() {
  final ddPlus = AudioTrack.fromParams(
      id: '0',
      typeOrder: 0,
      streamOrder: '0',
      codecId: 'A_EAC3',
      format: 'E-AC-3',
      channels: 6,
      isDefault: false,
      isForced: false);
  final trueHd = AudioTrack.fromParams(
      id: '1',
      typeOrder: 1,
      streamOrder: '1',
      codecId: 'A_TRUEHD',
      format: 'MLP FBA',
      channels: 8,
      isDefault: false,
      isForced: false);
  final dts = AudioTrack.fromParams(
      id: '2',
      typeOrder: 2,
      streamOrder: '2',
      codecId: 'A_DTS',
      format: 'DTS',
      channels: 6,
      isDefault: false,
      isForced: false);
  final dtsHDMA = AudioTrack.fromParams(
      id: '3',
      typeOrder: 3,
      streamOrder: '3',
      codecId: 'A_DTS',
      format: 'DTS',
      formatCommercialName: 'DTS-HD Master Audio',
      channels: 6,
      isDefault: false,
      isForced: false);
  final aacMC = AudioTrack.fromParams(
      id: '4',
      typeOrder: 4,
      streamOrder: '4',
      codecId: 'A_AAC-2',
      format: 'AAC',
      channels: 6,
      isDefault: false,
      isForced: false);
  final aacStereo = AudioTrack.fromParams(
      id: '5',
      typeOrder: 5,
      streamOrder: '5',
      codecId: 'A_AAC-2',
      format: 'AAC',
      channels: 2,
      isDefault: false,
      isForced: false);
  final aacMono = AudioTrack.fromParams(
      id: '6',
      typeOrder: 6,
      streamOrder: '6',
      codecId: 'A_AAC-2',
      format: 'AAC',
      channels: 1,
      isDefault: false,
      isForced: false);
  final dolbyDigital = AudioTrack.fromParams(
      id: '7',
      typeOrder: 7,
      streamOrder: '7',
      codecId: 'A_AC3',
      format: 'AC-3',
      channels: 6,
      isDefault: false,
      isForced: false);

  group('E-AC3', () {
    var tests = <SuggestTest>[
      SuggestTest.fromTracks(
          name: 'DD+ over TrueHD',
          expected: AudioFormat.dolbyDigitalPlus,
          tracks: [ddPlus, dolbyDigital, trueHd].build()),
      SuggestTest.fromTracks(
          name: 'TrueHD over Multi-Channel AAC, DTS, and DTS HD-MA',
          expected: AudioFormat.trueHD,
          tracks: [dts, trueHd, dtsHDMA, aacMC].build()),
      SuggestTest.fromTracks(
          name: 'Multi-Channel AAC over Stereo and Mono',
          expected: AudioFormat.aacMulti,
          tracks: [aacMC, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'Stereo over Mono',
          expected: AudioFormat.stereo,
          tracks: [aacStereo, aacMono].build()),
    ];

    for (var t in tests) {
      test(t.name, () {
        var finder = AudioFinder((af) => af..tracksByFormat = t.trackMap.toBuilder());
        var got = finder.bestForEAC3();
        expect(got.format, equals(t.expectedFormat));
      });
    }

    // TODO: MissingAudioSourceException
  });

  group('Multi-Channel AAC', () {
    var tests = <SuggestTest>[
      SuggestTest.fromTracks(
          name: 'Multi-Channel AAC over everything else',
          expected: AudioFormat.aacMulti,
          tracks: [dts, trueHd, dtsHDMA, aacMC, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'TrueHD over DTS HD-MA and Lossy',
          expected: AudioFormat.trueHD,
          tracks: [dts, trueHd, dtsHDMA, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'DTS HD-MA over Lossy',
          expected: AudioFormat.dtsHDMA,
          tracks: [dts, dtsHDMA, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'Dolby Digital Plus over others',
          expected: AudioFormat.dolbyDigitalPlus,
          tracks: [dts, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'Dolby Digital over others',
          expected: AudioFormat.dolbyDigital,
          tracks: [dts, aacStereo, aacMono, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'DTS over stereo and mono',
          expected: AudioFormat.dts,
          tracks: [dts, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'Stereo over mono',
          expected: AudioFormat.stereo,
          tracks: [aacStereo, aacMono].build()),
    ];

    for (var t in tests) {
      test(t.name, () {
        var finder = AudioFinder((af) => af..tracksByFormat = t.trackMap.toBuilder());
        var got = finder.bestForMultiChannelAAC();
        expect(got.format, equals(t.expectedFormat));
      });
    }

    // TODO: MissingAudioSourceException
  });

  group('Dolby Pro Logic II', () {
    var tests = <SuggestTest>[
      SuggestTest.fromTracks(
          name: 'TrueHD lossless over everything else',
          expected: AudioFormat.trueHD,
          tracks: [dts, trueHd, dtsHDMA, aacMC, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'DTS HD-MA lossless over everything else except TrueHD',
          expected: AudioFormat.dtsHDMA,
          tracks: [dts, dtsHDMA, aacMC, aacStereo, aacMono, ddPlus, dolbyDigital].build()),
      SuggestTest.fromTracks(
          name: 'Dolby Digital Plus over others',
          expected: AudioFormat.dolbyDigitalPlus,
          tracks: [ddPlus, dolbyDigital, dts, aacMC, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'Dolby Digital over others',
          expected: AudioFormat.dolbyDigital,
          tracks: [dolbyDigital, dts, aacMC, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'DTS over multi-channel AAC, stereo, and mono',
          expected: AudioFormat.dts,
          tracks: [dts, aacMC, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'Multi-channel AAC over stereo and mono',
          expected: AudioFormat.aacMulti,
          tracks: [aacMC, aacStereo, aacMono].build()),
      SuggestTest.fromTracks(
          name: 'Stereo over mono',
          expected: AudioFormat.stereo,
          tracks: [aacStereo, aacMono].build()),
    ];

    for (var t in tests) {
      test(t.name, () {
        var finder = AudioFinder((af) => af..tracksByFormat = t.trackMap.toBuilder());
        var got = finder.bestForDolbyProLogic2();
        expect(got.format, equals(t.expectedFormat));
      });
    }

    // TODO: MissingAudioSourceException
  });
}
