import 'package:equatable/equatable.dart';

import '../models/enums.dart';

abstract class CliException implements Exception {
  const CliException();
}

class FileNotFoundException extends CliException with EquatableMixin {
  final String filename;
  const FileNotFoundException(this.filename);

  @override
  List<Object> get props => [filename];

  @override
  String toString() => 'File not found: $filename';
}

class InvalidMetadataException extends CliException with EquatableMixin {
  final String message;
  final String filename;
  const InvalidMetadataException(this.message, this.filename);

  @override
  List<Object> get props => [message, filename];

  @override
  String toString() => 'Invalid media metadata: $message';
}

class MissingAudioSourceException extends CliException with EquatableMixin {
  final String purpose;
  final List<AudioFormat> availableFormats;
  const MissingAudioSourceException(this.purpose, this.availableFormats);

  @override
  List<Object> get props => [purpose, availableFormats];

  @override
  String toString() => 'Unable to find an appropriate audio source track for $purpose. '
      'Only found the following formats: ${availableFormats.join(", ")}';
}

class MissingRequiredArgumentException extends CliException with EquatableMixin {
  final String argument;
  const MissingRequiredArgumentException(this.argument);

  @override
  List<Object> get props => [argument];

  @override
  String toString() => 'Missing required argument: $argument.';
}

class OutputFileExistsException extends CliException with EquatableMixin {
  final String filename;
  final String fileModeFlagName;
  const OutputFileExistsException(this.filename, this.fileModeFlagName);

  @override
  List<Object> get props => [filename, fileModeFlagName];

  @override
  String toString() =>
      'Output file already exists: $filename. Use --$fileModeFlagName to append to it or overwrite it.';
}

class UpscalingRequiredException extends CliException with EquatableMixin {
  final VideoResolution target;
  final int width;
  const UpscalingRequiredException(this.target, this.width);

  @override
  List<Object> get props => [target, width];

  @override
  String toString() => 'Target resolution of ${target.name} requires upscaling from source '
      'width of $width. Specify the --force flag to enable upconversion.';
}

class ArgParsingFailedException with EquatableMixin implements Exception {
  final String targetType;
  final String value;
  ArgParsingFailedException(this.targetType, this.value);

  @override
  List<Object> get props => [targetType, value];

  @override
  String toString() => '$value cannot be parsed to $targetType';
}
