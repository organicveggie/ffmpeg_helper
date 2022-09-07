import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'mediainfo_exec.dart';
import 'models/mediainfo.dart';

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
  String? _filename;

  MediaRoot? _mediaRoot;

  MediaLoadingState get loadingState => _loadingState;
  set loadingState(MediaLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  String? get filename => _filename;
  set filename(String? filename) {
    _filename = filename;
    _loadingState = MediaLoadingState.loading;
    notifyListeners();
  }

  Media? get media => _mediaRoot?.media;

  set mediaRoot(MediaRoot mediaRoot) {
    _mediaRoot = mediaRoot;
    notifyListeners();
  }

  Future<MediaRoot> loadFile(String filename) {
    _filename = filename;
    loadingState = MediaLoadingState.loading;

    return runMediainfo(filename).then((mediaRoot) {
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
                    Text('loading ${model.filename}'),
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
        Text('Filename: ${model.filename}'),
        Expanded(
            child: DataTable(columns: const <DataColumn>[
          DataColumn(label: Expanded(child: Text('Type'))),
          DataColumn(label: Expanded(child: Text('Format'))),
          DataColumn(label: Expanded(child: Text('Language'))),
          DataColumn(label: Expanded(child: Text('Notes'))),
        ], rows: <DataRow>[
          ...List<DataRow>.generate(
              videoTracklist.length,
              (index) => DataRow(cells: <DataCell>[
                    const DataCell(Text('Video')),
                    DataCell(Text(videoTracklist[index].format)),
                    const DataCell(Text('n/a')),
                    DataCell(
                        Text('${videoTracklist[index].sizeName} ${videoTracklist[index].hdrName}'))
                  ])),
          ...List<DataRow>.generate(
              audioTracklist.length,
              (index) => DataRow(cells: <DataCell>[
                    const DataCell(Text('Audio')),
                    DataCell(Text(audioTracklist[index].format)),
                    DataCell(Text(audioTracklist[index].language ?? 'unknown')),
                    DataCell(Text(
                        '${audioTracklist[index].channels} channels, ${audioTracklist[index].bitRateMaxAsKbps} kbps'))
                  ]))
        ]))
      ],
    );
  }
}
