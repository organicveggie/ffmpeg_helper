// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

void main() {
  final defaultOptions = SuggestOptions.withDefaults(
      force: false, dpl2: false, mediaType: MediaType.movie, targetResolution: VideoResolution.uhd);

  test('mono track produces one track', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.aacMulti, true, false, channels: 1),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(3));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'AAC (mono)'),
        ]));
  });

  test('stereo track produces one track', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.aacMulti, true, false, channels: 2),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(3));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'AAC (stereo)'),
        ]));
  });

  test('Dolby Digital Plus no channels produces 2 audio streams, 6 operations', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, true, false, bitRate: 512000),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)')
        ]));
  });

  test('Dolby Digital Plus with 5.1 produces 2 audio streams, 6 operations', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, true, false,
              bitRate: 512000, channels: 6),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)')
        ]));
  });

  test('Dolby Digital Plus with 7.1 forces transcode to 5.1', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, true, false,
              bitRate: 512000, channels: 8),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _makeDDPConverter(),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)')
        ]));
  });

  test('Dolby Digital Plus with DPL2', () {
    var results = processAudioTracks(
        defaultOptions.rebuild((o) => o..generateDPL2 = true),
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, true, false,
              bitRate: 512000, channels: 6),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(10));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)'),
          (ComplexFilterBuilder()..filter = '[0:a]aresample=matrix_encoding=dplii[a]').build(),
          (DolbyProLogicAudioStreamConvertBuilder()
                ..inputFileId = 0
                ..srcStreamId = 0
                ..dstStreamId = 2
                ..format = AudioFormat.stereo
                ..channels = 2
                ..kbRate = 256)
              .build(),
          _dispositionDefault(2, false),
          _metadataTitle(2, 'AAC (Dolby Pro Logic II)'),
        ]));
  });

  test('Dolby Digital produces 2 streams, 6 operations', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigital, true, false, bitRate: 512000, channels: 6),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital'),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)'),
        ]));
  });

  test('Dolby Digital with commentary excluded', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.trueHD, true, false, bitRate: 512000, channels: 6),
          _makeAudioTrack(1, AudioFormat.dolbyDigital, true, false,
              bitRate: 512000,
              channels: 6,
              title: 'Director\'s commentary with other famous people'),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(9));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, AudioFormat.trueHD.name),
          _makeDDPConverter(srcStreamId: 0, dstStreamId: 1),
          _dispositionDefault(1, false),
          _metadataTitle(1, AudioFormat.dolbyDigitalPlus.name),
          _makeAacMultiConverter(srcStreamId: 0, dstStreamId: 2),
          _dispositionDefault(2, false),
          _metadataTitle(2, audioTitleAacMulti),
        ]));
  });
}

StreamDisposition _dispositionDefault(int streamId, bool isDefault) {
  return (StreamDispositionBuilder()
        ..trackType = TrackType.audio
        ..streamId = streamId
        ..isDefault = isDefault)
      .build();
}

AudioTrack _makeAudioTrack(int order, AudioFormat format, bool isDefault, bool isForced,
    {int? bitRate, BitRateMode? bitRateMode, int? channels, String? title}) {
  return AudioTrack.fromParams(
      id: '$order',
      codecId: format.codec,
      typeOrder: order,
      streamOrder: '$order',
      format: format.format,
      isDefault: isDefault,
      isForced: isForced,
      bitRate: bitRate,
      bitRateMode: bitRateMode,
      channels: channels,
      title: title);
}

StreamMetadata _metadataTitle(int streamId, String value) {
  return (StreamMetadataBuilder()
        ..trackType = TrackType.audio
        ..streamId = streamId
        ..name = 'title'
        ..value = value)
      .build();
}

StreamCopy _streamCopy(int sourceId, int destId) {
  return (StreamCopyBuilder()
        ..trackType = TrackType.audio
        ..inputFileId = 0
        ..srcStreamId = sourceId
        ..dstStreamId = destId)
      .build();
}

AudioStreamConvert _makeDDPConverter(
    {int inputFileId = 0, int srcStreamId = 0, int dstStreamId = 0}) {
  return (AudioStreamConvertBuilder()
        ..inputFileId = inputFileId
        ..srcStreamId = srcStreamId
        ..dstStreamId = dstStreamId
        ..format = AudioFormat.dolbyDigitalPlus
        ..channels = 6
        ..kbRate = 384)
      .build();
}

AudioStreamConvert _makeAacMultiConverter(
    {int inputFileId = 0, int srcStreamId = 0, int dstStreamId = 0}) {
  return (AudioStreamConvertBuilder()
        ..inputFileId = inputFileId
        ..srcStreamId = srcStreamId
        ..dstStreamId = dstStreamId
        ..format = AudioFormat.aacMulti
        ..channels = 6
        ..kbRate = 384)
      .build();
}
