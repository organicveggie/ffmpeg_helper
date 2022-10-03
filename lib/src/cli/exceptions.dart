import 'package:ffmpeg_helper/models/audio_format.dart';

abstract class CliException implements Exception {
  const CliException();
}

class FileNotFoundException extends CliException {
  final String filename;
  const FileNotFoundException(this.filename);

  @override
  String toString() => 'File not found: $filename';
}

class InvalidMetadataException extends CliException {
  final String message;
  final String filename;
  const InvalidMetadataException(this.message, this.filename);

  @override
  String toString() => 'Invalid media metadata: $message';
}

class MissingAudioSourceException extends CliException {
  final String purpose;
  final List<AudioFormat> availableFormats;
  const MissingAudioSourceException(this.purpose, this.availableFormats);

  @override
  String toString() => 'Unable to find an appropriate audio source track for $purpose. '
      'Only found the following formats: ${availableFormats.join(", ")}';
}

class MissingRequiredArgumentException extends CliException {
  final String argument;
  const MissingRequiredArgumentException(this.argument);

  @override
  String toString() => 'Missing required argument: $argument.';
}

class ArgParsingFailedException implements Exception {
  final String targetType;
  final String value;

  ArgParsingFailedException(this.targetType, this.value);

  @override
  String toString() => '$value cannot be parsed to $targetType';
}
