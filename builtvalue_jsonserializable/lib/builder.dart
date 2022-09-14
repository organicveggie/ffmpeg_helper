library builtvalue_jsonserializable.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builtvalue_jsonserializable_generator.dart';

Builder builtValueJsonSerializableBuilder(BuilderOptions options) =>
    SharedPartBuilder([BuiltValueJsonSerializableGenerator()], 'bvjs');
