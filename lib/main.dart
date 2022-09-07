import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'mediainfo_exec.dart';
import 'models/mediainfo.dart';
import 'models/media_file.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  Logger.root.level = Level.ALL;

  runApp(ChangeNotifierProvider(create: (context) => MediaModel(), child: const FFMpegHelperApp()));
}

enum MediaLoadingState {
  none,
  startLoading,
  loading,
  loaded,
  error;
}

class MediaModel extends ChangeNotifier {
  MediaLoadingState _loadingState = MediaLoadingState.none;
  MediaFile? _file;
  MediaRoot? _mediaRoot;

  MediaLoadingState get loadingState => _loadingState;
  set loadingState(MediaLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  String? get fileName => _file?.filename;
  String? get filePath => _file?.path;
  int? get fileSize => _file?.sizeInBytes;
  String? get fileSizeString => _file?.getFileSizeAsString(decimals: 1);

  String? get pathname => (_file == null) ? null : p.join(_file!.path, _file!.filename);
  set pathname(String? pathname) {
    if (pathname == null) {
      _file = null;
      return;
    }

    _setMediaFileFromPathname(pathname);
    _loadingState = MediaLoadingState.loading;
    notifyListeners();
  }

  void _setMediaFileFromPathname(String pathname) async {
    var f = File(pathname);
    var sizeInBytes = await f.length();
    _file = (MediaFileBuilder()
          ..path = p.dirname(pathname)
          ..filename = p.basename(pathname)
          ..sizeInBytes = sizeInBytes)
        .build();
  }

  Media? get media => _mediaRoot?.media;

  set mediaRoot(MediaRoot mediaRoot) {
    _mediaRoot = mediaRoot;
    notifyListeners();
  }

  Future<MediaRoot> loadFile(String pathname) {
    _setMediaFileFromPathname(pathname);
    loadingState = MediaLoadingState.loading;

    return runMediainfo(pathname).then((mediaRoot) {
      _mediaRoot = mediaRoot;
      loadingState = MediaLoadingState.loaded;
      return mediaRoot;
    });
  }
}

class FFMpegHelperApp extends StatelessWidget {
  const FFMpegHelperApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const HelperHomePage(title: 'ffmpeg helper'),
    );
  }
}

class HelperHomePage extends StatefulWidget {
  const HelperHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> {
  @override
  initState() {
    super.initState();
  }

  void _selectMediaFile() async {
    var model = context.read<MediaModel>();
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'movies',
      extensions: <String>['mkv', 'mp4', 'm4v'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      model.loadFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Consumer<MediaModel>(
        builder: (context, model, child) {
          switch (model.loadingState) {
            case MediaLoadingState.loading:
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Expanded(
                    child: Container(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(children: <Widget>[
                    Text('loading ${model.fileName}'),
                    const CircularProgressIndicator(),
                  ]),
                ))
              ]);
            case MediaLoadingState.loaded:
              return const MediaInfoPanel();
            default:
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(5.0),
                        child: const Text('no media file loaded')))
              ]);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectMediaFile,
        tooltip: 'Open Media',
        child: const Icon(Icons.file_open),
      ),
    );
  }
}

class MediaInfoPanel extends StatelessWidget {
  const MediaInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    var model = context.read<MediaModel>();
    var tracklist = model.media!.trackList;
    var audioTracklist = tracklist.audioTracks;
    var videoTracklist = tracklist.videoTracks;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('File: ${model.fileName}'),
            Text('Directory: ${model.filePath}'),
            Text('Size: ${model.fileSizeString}'),
          ],
        ),
        Expanded(
            child: DataTable(columns: const <DataColumn>[
          DataColumn(label: Expanded(child: Text('Type'))),
          DataColumn(label: Expanded(child: Text('Format'))),
          DataColumn(label: Expanded(child: Text('Language'))),
          DataColumn(label: Expanded(child: Text('Notes'))),
        ], rows: <DataRow>[
          ...List<DataRow>.generate(
              videoTracklist.length, (index) => _videoTrackAsDataRow(videoTracklist[index])),
          ...List<DataRow>.generate(
              audioTracklist.length, (index) => _audioTrackAsDataRow(audioTracklist[index]))
        ]))
      ],
    );
  }

  DataRow _videoTrackAsDataRow(VideoTrack t) {
    return DataRow(cells: <DataCell>[
      const DataCell(Text('Video')),
      DataCell(Text(t.format)),
      const DataCell(Text('n/a')),
      DataCell(Text('${t.sizeName}, ${t.hdrName}'))
    ]);
  }

  DataRow _audioTrackAsDataRow(AudioTrack t) {
    var bitRateMax = t.bitRateMaxAsKbps;
    var bitRate = (bitRateMax != null && bitRateMax > 0) ? bitRateMax : t.bitRate;
    return DataRow(cells: <DataCell>[
      const DataCell(Text('Audio')),
      DataCell(Text(t.format)),
      DataCell(Text(t.language ?? 'unknown')),
      DataCell(Text('${t.channels} channels, $bitRate kbps'))
    ]);
  }
}
