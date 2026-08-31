// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PhotoEntity _$PhotoEntityFromJson(Map<String, dynamic> json) {
  return _PhotoEntity.fromJson(json);
}

/// @nodoc
mixin _$PhotoEntity {
  String get id => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  int get width => throw _privateConstructorUsedError;
  int get height => throw _privateConstructorUsedError;
  DateTime get dateTaken => throw _privateConstructorUsedError;
  bool get isFavorited => throw _privateConstructorUsedError;
  double? get score => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PhotoEntityCopyWith<PhotoEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PhotoEntityCopyWith<$Res> {
  factory $PhotoEntityCopyWith(
          PhotoEntity value, $Res Function(PhotoEntity) then) =
      _$PhotoEntityCopyWithImpl<$Res, PhotoEntity>;
  @useResult
  $Res call(
      {String id,
      String path,
      int width,
      int height,
      DateTime dateTaken,
      bool isFavorited,
      double? score});
}

/// @nodoc
class _$PhotoEntityCopyWithImpl<$Res, $Val extends PhotoEntity>
    implements $PhotoEntityCopyWith<$Res> {
  _$PhotoEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? width = null,
    Object? height = null,
    Object? dateTaken = null,
    Object? isFavorited = null,
    Object? score = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      dateTaken: null == dateTaken
          ? _value.dateTaken
          : dateTaken // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PhotoEntityImplCopyWith<$Res>
    implements $PhotoEntityCopyWith<$Res> {
  factory _$$PhotoEntityImplCopyWith(
          _$PhotoEntityImpl value, $Res Function(_$PhotoEntityImpl) then) =
      __$$PhotoEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String path,
      int width,
      int height,
      DateTime dateTaken,
      bool isFavorited,
      double? score});
}

/// @nodoc
class __$$PhotoEntityImplCopyWithImpl<$Res>
    extends _$PhotoEntityCopyWithImpl<$Res, _$PhotoEntityImpl>
    implements _$$PhotoEntityImplCopyWith<$Res> {
  __$$PhotoEntityImplCopyWithImpl(
      _$PhotoEntityImpl _value, $Res Function(_$PhotoEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? path = null,
    Object? width = null,
    Object? height = null,
    Object? dateTaken = null,
    Object? isFavorited = null,
    Object? score = freezed,
  }) {
    return _then(_$PhotoEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      dateTaken: null == dateTaken
          ? _value.dateTaken
          : dateTaken // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFavorited: null == isFavorited
          ? _value.isFavorited
          : isFavorited // ignore: cast_nullable_to_non_nullable
              as bool,
      score: freezed == score
          ? _value.score
          : score // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PhotoEntityImpl extends _PhotoEntity {
  const _$PhotoEntityImpl(
      {required this.id,
      required this.path,
      required this.width,
      required this.height,
      required this.dateTaken,
      required this.isFavorited,
      required this.score})
      : super._();

  factory _$PhotoEntityImpl.fromJson(Map<String, dynamic> json) =>
      _$$PhotoEntityImplFromJson(json);

  @override
  final String id;
  @override
  final String path;
  @override
  final int width;
  @override
  final int height;
  @override
  final DateTime dateTaken;
  @override
  final bool isFavorited;
  @override
  final double? score;

  @override
  String toString() {
    return 'PhotoEntity(id: $id, path: $path, width: $width, height: $height, dateTaken: $dateTaken, isFavorited: $isFavorited, score: $score)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PhotoEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.dateTaken, dateTaken) ||
                other.dateTaken == dateTaken) &&
            (identical(other.isFavorited, isFavorited) ||
                other.isFavorited == isFavorited) &&
            (identical(other.score, score) || other.score == score));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, path, width, height, dateTaken, isFavorited, score);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PhotoEntityImplCopyWith<_$PhotoEntityImpl> get copyWith =>
      __$$PhotoEntityImplCopyWithImpl<_$PhotoEntityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PhotoEntityImplToJson(
      this,
    );
  }
}

abstract class _PhotoEntity extends PhotoEntity {
  const factory _PhotoEntity(
      {required final String id,
      required final String path,
      required final int width,
      required final int height,
      required final DateTime dateTaken,
      required final bool isFavorited,
      required final double? score}) = _$PhotoEntityImpl;
  const _PhotoEntity._() : super._();

  factory _PhotoEntity.fromJson(Map<String, dynamic> json) =
      _$PhotoEntityImpl.fromJson;

  @override
  String get id;
  @override
  String get path;
  @override
  int get width;
  @override
  int get height;
  @override
  DateTime get dateTaken;
  @override
  bool get isFavorited;
  @override
  double? get score;
  @override
  @JsonKey(ignore: true)
  _$$PhotoEntityImplCopyWith<_$PhotoEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
