import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:json_serializable/type_helper.dart' hide ClassConfig;

import 'typehelpers/config_types.dart';

part 'settings.g.dart';

abstract class Settings implements Built<Settings, SettingsBuilder> {
  static const _coreHelpers = <TypeHelper>[
    IterableHelper(),
    MapHelper(),
    EnumHelper(),
    ValueHelper(),
  ];

  static const defaultHelpers = <TypeHelper>[
    BigIntHelper(),
    DateTimeHelper(),
    DurationHelper(),
    JsonHelper(),
    UriHelper(),
  ];

  ClassConfig get config;
  BuiltList<TypeHelper> get typeHelpers;

  Iterable<TypeHelper> get allHelpers => const <TypeHelper>[
        ConvertHelper(),
        JsonConverterHelper(),
        GenericFactoryHelper(),
      ].followedBy(typeHelpers).followedBy(_coreHelpers);

  Settings._();
  factory Settings([void Function(SettingsBuilder) updates]) = _$Settings;

  factory Settings.fromJsonSerializable({
    JsonSerializable? config,
    List<TypeHelper>? typeHelpers,
  }) {
    var classConfig =
        config != null ? ClassConfig.fromJsonSerializable(config) : ClassConfig.defaults;
    return Settings((b) => b
      ..config = classConfig.toBuilder()
      ..typeHelpers = BuiltList<TypeHelper>.of(typeHelpers ?? defaultHelpers).toBuilder());
  }

  factory Settings.withDefaultHelpers(
    Iterable<TypeHelper> typeHelpers, {
    JsonSerializable? config,
  }) {
    var classConfig =
        config != null ? ClassConfig.fromJsonSerializable(config) : ClassConfig.defaults;
    return Settings((b) => b
      ..config = classConfig.toBuilder()
      ..typeHelpers = BuiltList<TypeHelper>.of(typeHelpers.followedBy(defaultHelpers)).toBuilder());
  }
}
