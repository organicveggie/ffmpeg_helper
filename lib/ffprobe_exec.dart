const _defaultFfprobeBin = '/usr/bin/ffprobe';

Future<void> runFfprobe(String pathname, {String? ffprobeBin = _defaultFfprobeBin}) async {
  // fprobe -v quiet -print_format json -show_format -show_streams "lolwut.mp4"
}
