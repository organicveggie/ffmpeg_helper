import 'package:built_value/built_value.dart';

import 'package:ffmpeg_helper/models.dart' as models;

part 'wrappers.g.dart';

abstract class AudioTrack implements Built<AudioTrack, AudioTrackBuilder> {
  models.AudioFormat get format;
  models.AudioTrack get track;
  int get orderId;

  AudioTrack._();
  factory AudioTrack(int orderId, models.AudioTrack track) {
    return _$AudioTrack._(format: track.toAudioFormat(), track: track, orderId: orderId);
  }
}

abstract class TextTrack implements Built<TextTrack, TextTrackBuilder> {
  int get orderId;
  models.TextTrack get track;

  TextTrack._();
  factory TextTrack(int orderId, models.TextTrack track) {
    return _$TextTrack._(orderId: orderId, track: track);
  }
}
