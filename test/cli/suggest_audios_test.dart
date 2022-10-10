// ignore: depend_on_referenced_packages
import 'package:built_collection/built_collection.dart';
import 'package:ffmpeg_helper/models.dart';
import 'package:ffmpeg_helper/src/cli/conversions.dart';
import 'package:ffmpeg_helper/src/cli/suggest.dart';
import 'package:test/test.dart';

void main() {
  final defaultOptions = (SuggestOptionsBuilder()
        ..forceUpscaling = false
        ..generateDPL2 = false
        ..mediaType = MediaType.movie
        ..targetResolution = VideoResolution.uhd)
      .build();

  final convertAacMulti = (AudioStreamConvertBuilder()
        ..inputFileId = 0
        ..srcStreamId = 0
        ..dstStreamId = 1
        ..format = AudioFormat.aacMulti
        ..channels = 6
        ..kbRate = 384)
      .build();

  final convertDDPlus = (AudioStreamConvertBuilder()
        ..inputFileId = 0
        ..srcStreamId = 0
        ..dstStreamId = 0
        ..format = AudioFormat.dolbyDigitalPlus
        ..channels = 6
        ..kbRate = 384)
      .build();

  test('mono track produces one track', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.aacMulti, 1, true, false),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(2));
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
          _makeAudioTrack(0, AudioFormat.aacMulti, 2, true, false),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(2));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'AAC (stereo)'),
          (StreamMetadataBuilder()
                ..trackType = TrackType.audio
                ..streamId = 0
                ..name = 'title'
                ..value = 'AAC (stereo')
              .build(),
        ]));
  });

  test('Dolby Digital Plus produces 2 audio streams, 6 operations', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, 6, true, false, bitRate: 512000),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          convertAacMulti,
          _dispositionDefault(1, false),
          _metadataTitle(0, 'AAC (5.1)')
        ]));
  });

  test('Dolby Digital Plus with DPL2', () {
    var results = processAudioTracks(
        defaultOptions.rebuild((o) => o..generateDPL2 = true),
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.dolbyDigitalPlus, 6, true, false, bitRate: 512000),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(6));

    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          convertAacMulti,
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)'),
          (AudioStreamConvertBuilder()
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
          _makeAudioTrack(0, AudioFormat.dolbyDigital, 6, true, false, bitRate: 512000),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(4));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          _streamCopy(0, 0),
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital'),
          convertAacMulti,
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)'),
        ]));
  });

  test('TrueHD converted', () {
    var results = processAudioTracks(
        defaultOptions,
        <AudioTrack>[
          _makeAudioTrack(0, AudioFormat.trueHD, 6, true, false, bitRate: 512000),
        ].build());
    expect(results, isNotNull);
    expect(results, hasLength(4));
    expect(
        results,
        containsAllInOrder(<StreamOption>[
          convertDDPlus,
          _dispositionDefault(0, true),
          _metadataTitle(0, 'Dolby Digital Plus'),
          convertAacMulti,
          _dispositionDefault(1, false),
          _metadataTitle(1, 'AAC (5.1)'),
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

AudioTrack _makeAudioTrack(
    int order, AudioFormat format, int channels, bool isDefault, bool isForced,
    {int? bitRate}) {
  return AudioTrack.fromParams(
      id: '$order',
      codecId: format.codec,
      typeOrder: order,
      streamOrder: '$order',
      format: format.format,
      isDefault: isDefault,
      isForced: isForced,
      channels: channels,
      bitRate: bitRate);
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
