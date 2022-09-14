import 'package:analyzer/dart/constant/value.dart';
import 'package:built_value/built_value.dart';
import 'package:json_annotation/json_annotation.dart';

part 'config_types.g.dart';

abstract class KeyConfig implements Built<KeyConfig, KeyConfigBuilder> {
  String? get defaultValue;

  bool get disallowNullValue;

  bool get ignore;

  bool get includeIfNull;

  String get name;

  bool get required;

  String? get unknownEnumValue;

  String? get readValueFunctionName;

  KeyConfig._();
  factory KeyConfig([void Function(KeyConfigBuilder) updates]) = _$KeyConfig;
}

abstract class ClassConfig implements Built<ClassConfig, ClassConfigBuilder> {
  bool get anyMap;
  bool get checked;
  String get constructor;
  bool get createFactory;
  bool get createToJson;
  bool get createFieldMap;
  bool get disallowUnrecognizedKeys;
  bool get explicitToJson;
  FieldRename get fieldRename;
  bool get genericArgumentFactories;
  bool get ignoreUnannotated;
  bool get includeIfNull;
  Map<String, String> get ctorParamDefaults;
  List<DartObject> get converters;

  ClassConfig._();
  factory ClassConfig([void Function(ClassConfigBuilder) updates]) = _$ClassConfig;
  factory ClassConfig.fromJsonSerializable(JsonSerializable config) => ClassConfig((b) => b
    ..anyMap = config.anyMap ?? ClassConfig.defaults.anyMap
    ..checked = config.checked ?? ClassConfig.defaults.checked
    ..constructor = config.constructor ?? ClassConfig.defaults.constructor
    ..createFactory = config.createFactory ?? ClassConfig.defaults.createFactory
    ..createFieldMap = config.createFieldMap ?? ClassConfig.defaults.createFieldMap
    ..createToJson = config.createToJson ?? ClassConfig.defaults.createToJson
    ..disallowUnrecognizedKeys =
        config.disallowUnrecognizedKeys ?? ClassConfig.defaults.disallowUnrecognizedKeys
    ..explicitToJson = config.explicitToJson ?? ClassConfig.defaults.explicitToJson
    ..fieldRename = config.fieldRename ?? ClassConfig.defaults.fieldRename
    ..genericArgumentFactories =
        config.genericArgumentFactories ?? ClassConfig.defaults.genericArgumentFactories
    ..ignoreUnannotated = config.ignoreUnannotated ?? ClassConfig.defaults.ignoreUnannotated
    ..includeIfNull = config.includeIfNull ?? ClassConfig.defaults.includeIfNull);

  static final defaults = ClassConfig((b) => b
    ..anyMap = false
    ..checked = false
    ..constructor = ''
    ..createFactory = true
    ..createFieldMap = false
    ..createToJson = true
    ..disallowUnrecognizedKeys = false
    ..explicitToJson = false
    ..fieldRename = FieldRename.none
    ..genericArgumentFactories = false
    ..ignoreUnannotated = false
    ..includeIfNull = true);

  JsonSerializable toJsonSerializable() => JsonSerializable(
        checked: checked,
        anyMap: anyMap,
        constructor: constructor,
        createFactory: createFactory,
        createToJson: createToJson,
        createFieldMap: createFieldMap,
        ignoreUnannotated: ignoreUnannotated,
        explicitToJson: explicitToJson,
        includeIfNull: includeIfNull,
        genericArgumentFactories: genericArgumentFactories,
        fieldRename: fieldRename,
        disallowUnrecognizedKeys: disallowUnrecognizedKeys,
        // TODO typeConverters = []
      );
}
