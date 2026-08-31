// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PostDraft _$PostDraftFromJson(Map<String, dynamic> json) {
  return _PostDraft.fromJson(json);
}

/// @nodoc
mixin _$PostDraft {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  String get caption => throw _privateConstructorUsedError;
  @HiveField(2)
  List<String> get hashtags => throw _privateConstructorUsedError;
  @HiveField(3)
  String? get imageUrl => throw _privateConstructorUsedError;
  @HiveField(4)
  String get platform => throw _privateConstructorUsedError;
  @HiveField(5)
  DateTime get createdAt => throw _privateConstructorUsedError;
  @HiveField(6)
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PostDraftCopyWith<PostDraft> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostDraftCopyWith<$Res> {
  factory $PostDraftCopyWith(PostDraft value, $Res Function(PostDraft) then) =
      _$PostDraftCopyWithImpl<$Res, PostDraft>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String caption,
      @HiveField(2) List<String> hashtags,
      @HiveField(3) String? imageUrl,
      @HiveField(4) String platform,
      @HiveField(5) DateTime createdAt,
      @HiveField(6) DateTime updatedAt});
}

/// @nodoc
class _$PostDraftCopyWithImpl<$Res, $Val extends PostDraft>
    implements $PostDraftCopyWith<$Res> {
  _$PostDraftCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? caption = null,
    Object? hashtags = null,
    Object? imageUrl = freezed,
    Object? platform = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      hashtags: null == hashtags
          ? _value.hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PostDraftImplCopyWith<$Res>
    implements $PostDraftCopyWith<$Res> {
  factory _$$PostDraftImplCopyWith(
          _$PostDraftImpl value, $Res Function(_$PostDraftImpl) then) =
      __$$PostDraftImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String caption,
      @HiveField(2) List<String> hashtags,
      @HiveField(3) String? imageUrl,
      @HiveField(4) String platform,
      @HiveField(5) DateTime createdAt,
      @HiveField(6) DateTime updatedAt});
}

/// @nodoc
class __$$PostDraftImplCopyWithImpl<$Res>
    extends _$PostDraftCopyWithImpl<$Res, _$PostDraftImpl>
    implements _$$PostDraftImplCopyWith<$Res> {
  __$$PostDraftImplCopyWithImpl(
      _$PostDraftImpl _value, $Res Function(_$PostDraftImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? caption = null,
    Object? hashtags = null,
    Object? imageUrl = freezed,
    Object? platform = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$PostDraftImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      caption: null == caption
          ? _value.caption
          : caption // ignore: cast_nullable_to_non_nullable
              as String,
      hashtags: null == hashtags
          ? _value._hashtags
          : hashtags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostDraftImpl extends _PostDraft with DiagnosticableTreeMixin {
  const _$PostDraftImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.caption,
      @HiveField(2) required final List<String> hashtags,
      @HiveField(3) required this.imageUrl,
      @HiveField(4) required this.platform,
      @HiveField(5) required this.createdAt,
      @HiveField(6) required this.updatedAt})
      : _hashtags = hashtags,
        super._();

  factory _$PostDraftImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostDraftImplFromJson(json);

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String caption;
  final List<String> _hashtags;
  @override
  @HiveField(2)
  List<String> get hashtags {
    if (_hashtags is EqualUnmodifiableListView) return _hashtags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_hashtags);
  }

  @override
  @HiveField(3)
  final String? imageUrl;
  @override
  @HiveField(4)
  final String platform;
  @override
  @HiveField(5)
  final DateTime createdAt;
  @override
  @HiveField(6)
  final DateTime updatedAt;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'PostDraft(id: $id, caption: $caption, hashtags: $hashtags, imageUrl: $imageUrl, platform: $platform, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'PostDraft'))
      ..add(DiagnosticsProperty('id', id))
      ..add(DiagnosticsProperty('caption', caption))
      ..add(DiagnosticsProperty('hashtags', hashtags))
      ..add(DiagnosticsProperty('imageUrl', imageUrl))
      ..add(DiagnosticsProperty('platform', platform))
      ..add(DiagnosticsProperty('createdAt', createdAt))
      ..add(DiagnosticsProperty('updatedAt', updatedAt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostDraftImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.caption, caption) || other.caption == caption) &&
            const DeepCollectionEquality().equals(other._hashtags, _hashtags) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      caption,
      const DeepCollectionEquality().hash(_hashtags),
      imageUrl,
      platform,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PostDraftImplCopyWith<_$PostDraftImpl> get copyWith =>
      __$$PostDraftImplCopyWithImpl<_$PostDraftImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostDraftImplToJson(
      this,
    );
  }
}

abstract class _PostDraft extends PostDraft {
  const factory _PostDraft(
      {@HiveField(0) required final String id,
      @HiveField(1) required final String caption,
      @HiveField(2) required final List<String> hashtags,
      @HiveField(3) required final String? imageUrl,
      @HiveField(4) required final String platform,
      @HiveField(5) required final DateTime createdAt,
      @HiveField(6) required final DateTime updatedAt}) = _$PostDraftImpl;
  const _PostDraft._() : super._();

  factory _PostDraft.fromJson(Map<String, dynamic> json) =
      _$PostDraftImpl.fromJson;

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  String get caption;
  @override
  @HiveField(2)
  List<String> get hashtags;
  @override
  @HiveField(3)
  String? get imageUrl;
  @override
  @HiveField(4)
  String get platform;
  @override
  @HiveField(5)
  DateTime get createdAt;
  @override
  @HiveField(6)
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$PostDraftImplCopyWith<_$PostDraftImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
