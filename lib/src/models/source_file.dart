import 'dart:io';

import 'package:path/path.dart' as p;

abstract class SourceFile {
  bool exists();

  String getNameForMediaInfo();

  String getNameForRemux();
}

class BluRaySource implements SourceFile {
  final String _folderName;
  final String _playlistFilename;

  const BluRaySource._(this._folderName, this._playlistFilename);

  factory BluRaySource.create(String folderName, String playlist) {
    final playlistFile = p.join(folderName, 'BDMV', 'PLAYLIST', '$playlist.mpls');
    return BluRaySource._(folderName, playlistFile);
  }

  @override
  bool exists() => File(_playlistFilename).existsSync();

  @override
  String getNameForMediaInfo() => _playlistFilename;

  @override
  String getNameForRemux() => _folderName;
}

class SingleFileSource implements SourceFile {
  final String _filename;

  SingleFileSource(this._filename);

  @override
  bool exists() => File(_filename).existsSync();

  @override
  String getNameForMediaInfo() => _filename;

  @override
  String getNameForRemux() => _filename;
}
