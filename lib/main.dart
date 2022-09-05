import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> {
  @override
  initState() {
    super.initState();
  }

  void _pickMediaFile() async {
    var model = context.read<MediaModel>();
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video, lockParentWindow: true);

    if (result != null) {
      if (result.files.isNotEmpty) {
        var f = result.files.first;
        model.filename = f.path ?? f.name;
        model.loadingState = MediaLoadingState.startLoading;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Consumer<MediaModel>(
            builder: (context, model, child) {
              switch (model.loadingState) {
                case MediaLoadingState.startLoading:
                  return MediaInfo(filename: model.filename!);
                case MediaLoadingState.loaded:
                  return Text('loaded ${model.filename}');
                default:
                  return const Text('no media file loaded');
              }
            },
          ),
        ],
      ),

      // body: Center(
      //   // Center is a layout widget. It takes a single child and positions it
      //   // in the middle of the parent.
      //   child: Column(
      //     // Column is also a layout widget. It takes a list of children and
      //     // arranges them vertically. By default, it sizes itself to fit its
      //     // children horizontally, and tries to be as tall as its parent.
      //     //
      //     // Invoke "debug painting" (press "p" in the console, choose the
      //     // "Toggle Debug Paint" action from the Flutter Inspector in Android
      //     // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
      //     // to see the wireframe for each widget.
      //     //
      //     // Column has various properties to control how it sizes itself and
      //     // how it positions its children. Here we use mainAxisAlignment to
      //     // center the children vertically; the main axis here is the vertical
      //     // axis because Columns are vertical (the cross axis would be
      //     // horizontal).
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: <Widget>[
      //       const Text(
      //         'You have pushed the button this many times:',
      //       ),
      //       Text(
      //         '$_counter',
      //         style: Theme.of(context).textTheme.headline4,
      //       ),
      //     ],
      //   ),
      // ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickMediaFile,
        tooltip: 'Open Media',
        child: const Icon(Icons.file_open),
      ),
    );
  }
}

class MediaModel extends ChangeNotifier {
  MediaLoadingState _loadingState = MediaLoadingState.none;
  String? _filename;

  Future<MediaRoot>? _futureMediaRoot;
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

  Future<MediaRoot>? get futureMediaRoot => _futureMediaRoot;
  set futureMediaRoot(Future<MediaRoot>? f) {
    _futureMediaRoot = f;
    _loadingState = (f == null) ? MediaLoadingState.none : MediaLoadingState.loading;
    notifyListeners();
  }

  Media? get media => _mediaRoot?.media;

  set mediaRoot(MediaRoot mediaRoot) {
    _mediaRoot = mediaRoot;
    notifyListeners();
  }
}

class MediaPanel extends StatelessWidget {
  const MediaPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaModel>(
      builder: (context, model, child) {
        switch (model.loadingState) {
          case MediaLoadingState.loading:
            return FutureBuilder<MediaRoot>(
              future: model._futureMediaRoot,
              builder: ((context, AsyncSnapshot<MediaRoot> snapshot) {
                if (snapshot.hasData) {
                  return Center(child: Text('Successfully loaded ${model.filename}'));
                }
                return Center(
                    child: Column(children: <Widget>[
                  Text('loading ${model.filename}'),
                  const CircularProgressIndicator(),
                ]));
              }),
            );
          case MediaLoadingState.loaded:
            return Text('loaded ${model.filename}');
          case MediaLoadingState.error:
            return Text('failed to load ${model.filename}');
          default:
            return const Text('no media file loaded');
        }
      },
    );
  }
}

class MediaInfo extends StatefulWidget {
  MediaInfo({required this.filename, super.key});
  final String filename;
  Future<MediaRoot>? mediaRoot;

  @override
  State<StatefulWidget> createState() => _MediaInfoState();
}

class _MediaInfoState extends State<MediaInfo> {
  _MediaInfoState();

  final log = Logger('_MediaInfoState');

  @override
  void initState() {
    super.initState();
    widget.mediaRoot = runMediainfo(widget.filename);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: widget.mediaRoot!,
        builder: (context, AsyncSnapshot<MediaRoot> snapshot) {
          if (snapshot.hasData) {
            return Center(child: Text('Successfully loaded ${widget.filename}'));
          }
          return Center(
            child: Column(children: <Widget>[
              Text('loading ${widget.filename}'),
              const CircularProgressIndicator(),
            ]),
          );
        });
  }
}
