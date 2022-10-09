import 'package:built_value/built_value.dart';

import '../src/cli/enums.dart';
import 'mediainfo.dart' as mediainfo;

part 'wrappers.g.dart';

abstract class AudioTrack implements Built<AudioTrack, AudioTrackBuilder> {
  AudioFormat get format;
  mediainfo.AudioTrack get track;
  int get orderId;

  AudioTrack._();
  factory AudioTrack(int orderId, mediainfo.AudioTrack track) {
    return _$AudioTrack._(format: track.toAudioFormat(), track: track, orderId: orderId);
  }
}

abstract class TextTrack implements Built<TextTrack, TextTrackBuilder> {
  int get orderId;
  mediainfo.TextTrack get track;

  TextTrack._();
  factory TextTrack(int orderId, mediainfo.TextTrack track) {
    return _$TextTrack._(orderId: orderId, track: track);
  }
}
