import 'package:ffmpeg_helper/models/audio_format.dart';

class InvalidMetadataException implements Exception {
  final String message;
  final String filename;
  const InvalidMetadataException(this.message, this.filename);

  @override
  String toString() => 'Invalid media metadata: $message';
}

class MissingAudioSourceException implements Exception {
  final String purpose;
  final List<AudioFormat> availableFormats;
  const MissingAudioSourceException(this.purpose, this.availableFormats);

  @override
  String toString() => 'Unable to find an appropriate audio source track for $purpose. '
      'Only found the following formats: ${availableFormats.join(", ")}';
}

class MissingRequiredArgumentException implements Exception {
  final String argument;
  const MissingRequiredArgumentException(this.argument);

  @override
  String toString() => 'Missing required argument: $argument.';
}
