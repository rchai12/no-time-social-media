// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_platform.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SocialPlatform _$SocialPlatformFromJson(Map<String, dynamic> json) {
  return _SocialPlatform.fromJson(json);
}

/// @nodoc
mixin _$SocialPlatform {
  @HiveField(0)
  String get name => throw _privateConstructorUsedError;
  @HiveField(1)
  String get displayName => throw _privateConstructorUsedError;
  @HiveField(2)
  bool get isEnabled => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SocialPlatformCopyWith<SocialPlatform> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialPlatformCopyWith<$Res> {
  factory $SocialPlatformCopyWith(
          SocialPlatform value, $Res Function(SocialPlatform) then) =
      _$SocialPlatformCopyWithImpl<$Res, SocialPlatform>;
  @useResult
  $Res call(
      {@HiveField(0) String name,
      @HiveField(1) String displayName,
      @HiveField(2) bool isEnabled});
}

/// @nodoc
class _$SocialPlatformCopyWithImpl<$Res, $Val extends SocialPlatform>
    implements $SocialPlatformCopyWith<$Res> {
  _$SocialPlatformCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? displayName = null,
    Object? isEnabled = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialPlatformImplCopyWith<$Res>
    implements $SocialPlatformCopyWith<$Res> {
  factory _$$SocialPlatformImplCopyWith(_$SocialPlatformImpl value,
          $Res Function(_$SocialPlatformImpl) then) =
      __$$SocialPlatformImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String name,
      @HiveField(1) String displayName,
      @HiveField(2) bool isEnabled});
}

/// @nodoc
class __$$SocialPlatformImplCopyWithImpl<$Res>
    extends _$SocialPlatformCopyWithImpl<$Res, _$SocialPlatformImpl>
    implements _$$SocialPlatformImplCopyWith<$Res> {
  __$$SocialPlatformImplCopyWithImpl(
      _$SocialPlatformImpl _value, $Res Function(_$SocialPlatformImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? displayName = null,
    Object? isEnabled = null,
  }) {
    return _then(_$SocialPlatformImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SocialPlatformImpl extends _SocialPlatform
    with DiagnosticableTreeMixin {
  const _$SocialPlatformImpl(
      {@HiveField(0) required this.name,
      @HiveField(1) required this.displayName,
      @HiveField(2) required this.isEnabled})
      : super._();

  factory _$SocialPlatformImpl.fromJson(Map<String, dynamic> json) =>
      _$$SocialPlatformImplFromJson(json);

  @override
  @HiveField(0)
  final String name;
  @override
  @HiveField(1)
  final String displayName;
  @override
  @HiveField(2)
  final bool isEnabled;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'SocialPlatform(name: $name, displayName: $displayName, isEnabled: $isEnabled)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'SocialPlatform'))
      ..add(DiagnosticsProperty('name', name))
      ..add(DiagnosticsProperty('displayName', displayName))
      ..add(DiagnosticsProperty('isEnabled', isEnabled));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialPlatformImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, name, displayName, isEnabled);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialPlatformImplCopyWith<_$SocialPlatformImpl> get copyWith =>
      __$$SocialPlatformImplCopyWithImpl<_$SocialPlatformImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SocialPlatformImplToJson(
      this,
    );
  }
}

abstract class _SocialPlatform extends SocialPlatform {
  const factory _SocialPlatform(
      {@HiveField(0) required final String name,
      @HiveField(1) required final String displayName,
      @HiveField(2) required final bool isEnabled}) = _$SocialPlatformImpl;
  const _SocialPlatform._() : super._();

  factory _SocialPlatform.fromJson(Map<String, dynamic> json) =
      _$SocialPlatformImpl.fromJson;

  @override
  @HiveField(0)
  String get name;
  @override
  @HiveField(1)
  String get displayName;
  @override
  @HiveField(2)
  bool get isEnabled;
  @override
  @JsonKey(ignore: true)
  _$$SocialPlatformImplCopyWith<_$SocialPlatformImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
