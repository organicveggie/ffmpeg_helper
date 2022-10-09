import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

import 'audio_track.dart';
import 'general_track.dart';
import 'menu_track.dart';
import 'text_track.dart';
import 'track.dart';
import 'video_track.dart';

part 'track_list.g.dart';

@JsonSerializable()
class TrackList with EquatableMixin {
  const TrackList(List<Track>? tracks,
      {this.generalTrack,
      List<AudioTrack>? audioTracks,
      List<MenuTrack>? menuTracks,
      List<TextTrack>? textTracks,
      List<VideoTrack>? videoTracks})
      : tracks = tracks ?? const [],
        audioTracks = audioTracks ?? const [],
        menuTracks = menuTracks ?? const [],
        textTracks = textTracks ?? const [],
        videoTracks = videoTracks ?? const [];

  final List<Track> tracks;
  final GeneralTrack? generalTrack;
  final List<AudioTrack> audioTracks;
  final List<MenuTrack> menuTracks;
  final List<TextTrack> textTracks;
  final List<VideoTrack> videoTracks;

  factory TrackList.fromJson(List<dynamic> jsonTracks) {
    GeneralTrack? general;
    var audioTracks = <AudioTrack>[];
    var menuTracks = <MenuTrack>[];
    var textTracks = <TextTrack>[];
    var videoTracks = <VideoTrack>[];

    for (var e in jsonTracks) {
      var em = e as Map<String, dynamic>;
      var t = Track.fromJson(em);
      switch (t.type) {
        case TrackType.audio:
          audioTracks.add(AudioTrack.fromJson(em));
          break;
        case TrackType.general:
          general = GeneralTrack.fromJson(em);
          break;
        case TrackType.menu:
          menuTracks.add(MenuTrack.fromJson(em));
          break;
        case TrackType.text:
          textTracks.add(TextTrack.fromJson(em));
          break;
        case TrackType.video:
          videoTracks.add(VideoTrack.fromJson(em));
          break;
      }
    }

    var tracks = <Track>[
      ...videoTracks,
      ...audioTracks,
      ...textTracks,
      ...menuTracks,
    ];
    if (general != null) {
      tracks.add(general);
    }

    return TrackList(tracks,
        generalTrack: general,
        audioTracks: audioTracks,
        menuTracks: menuTracks,
        textTracks: textTracks,
        videoTracks: videoTracks);
  }

  Map<String, dynamic> toJson() {
    List<dynamic> json = [];
    for (final t in tracks) {
      json.add(t.toJson());
    }
    return {'tracks': json};
  }

  @override
  List<Object?> get props => [tracks];
}
