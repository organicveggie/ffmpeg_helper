import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/models/audio_format.dart';
import 'package:ffmpeg_helper/models/mediainfo.dart';
import 'package:ffmpeg_helper/models/wrappers.dart' as wrappers;
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

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
    test('DD+ over TrueHD', () async {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(1, ddPlus),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(2, dolbyDigital),
          AudioFormat.trueHD: wrappers.AudioTrack(3, trueHd)
        }));
      var got = finder.bestForEAC3();
      expect(got.format, equals(AudioFormat.dolbyDigitalPlus));
    });

    test('TrueHD over Multi-Channel AAC, DTS, and DTS HD-MA', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.trueHD: wrappers.AudioTrack(2, trueHd),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.aacMulti: wrappers.AudioTrack(4, aacMC),
        }));
      var got = finder.bestForEAC3();
      expect(got.format, equals(AudioFormat.trueHD));
    });

    test('Multi-Channel AAC over Stereo and Mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.aacMulti: wrappers.AudioTrack(1, aacMC),
          AudioFormat.stereo: wrappers.AudioTrack(2, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(3, aacMono),
        }));
      var got = finder.bestForEAC3();
      expect(got.format, equals(AudioFormat.aacMulti));
    });

    test('Stereo over Mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.stereo: wrappers.AudioTrack(1, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(2, aacMono),
        }));
      var got = finder.bestForEAC3();
      expect(got.format, equals(AudioFormat.stereo));
    });

    // TODO: MissingAudioSourceException
  });

  group('Multi-Channel AAC', () {
    test('Multi-Channel AAC over everything else', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.trueHD: wrappers.AudioTrack(2, trueHd),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.aacMulti: wrappers.AudioTrack(4, aacMC),
          AudioFormat.stereo: wrappers.AudioTrack(5, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(6, aacMono),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(7, dolbyDigital),
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(8, ddPlus),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.aacMulti));
    });

    test('Lossless over lossy', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.trueHD: wrappers.AudioTrack(2, trueHd),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.stereo: wrappers.AudioTrack(4, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(5, aacMono),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(6, dolbyDigital),
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(7, ddPlus),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.trueHD));

      finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.stereo: wrappers.AudioTrack(4, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(5, aacMono),
        }));
      got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.dtsHDMA));
    });

    test('Dolby Digital Plus over others', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(1, ddPlus),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(2, dolbyDigital),
          AudioFormat.dts: wrappers.AudioTrack(3, dts),
          AudioFormat.stereo: wrappers.AudioTrack(4, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(5, aacMono),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.dolbyDigitalPlus));
    });

    test('Dolby Digital over others', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dolbyDigital: wrappers.AudioTrack(1, dolbyDigital),
          AudioFormat.dts: wrappers.AudioTrack(2, dts),
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.dolbyDigital));
    });

    test('DTS over stereo and mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(2, dts),
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.dts));
    });

    test('Stereo over mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForMultiChannelAAC();
      expect(got.format, equals(AudioFormat.stereo));
    });

    // TODO: MissingAudioSourceException
  });

  group('Dolby Pro Logic II', () {
    test('Lossless over everything else', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.trueHD: wrappers.AudioTrack(2, trueHd),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.aacMulti: wrappers.AudioTrack(4, aacMC),
          AudioFormat.stereo: wrappers.AudioTrack(5, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(6, aacMono),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(7, dolbyDigital),
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(8, ddPlus),
        }));
      var got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.trueHD));

      finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(1, dts),
          AudioFormat.dtsHDMA: wrappers.AudioTrack(3, dtsHDMA),
          AudioFormat.aacMulti: wrappers.AudioTrack(4, aacMC),
          AudioFormat.stereo: wrappers.AudioTrack(5, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(6, aacMono),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(7, dolbyDigital),
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(8, ddPlus),
        }));
      got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.dtsHDMA));
    });

    test('Dolby Digital Plus over others', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dolbyDigitalPlus: wrappers.AudioTrack(1, ddPlus),
          AudioFormat.dolbyDigital: wrappers.AudioTrack(2, dolbyDigital),
          AudioFormat.dts: wrappers.AudioTrack(3, dts),
          AudioFormat.stereo: wrappers.AudioTrack(4, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(5, aacMono),
        }));
      var got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.dolbyDigitalPlus));
    });

    test('Dolby Digital over others', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dolbyDigital: wrappers.AudioTrack(1, dolbyDigital),
          AudioFormat.dts: wrappers.AudioTrack(2, dts),
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.dolbyDigital));
    });

    test('DTS over stereo and mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.dts: wrappers.AudioTrack(2, dts),
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.dts));
    });

    test('Stereo over mono', () {
      var finder = AudioFinder((af) => af
        ..tracksByFormat.addAll({
          AudioFormat.stereo: wrappers.AudioTrack(3, aacStereo),
          AudioFormat.mono: wrappers.AudioTrack(4, aacMono),
        }));
      var got = finder.bestForDolbyProLogic2();
      expect(got.format, equals(AudioFormat.stereo));
    });
  });
}
