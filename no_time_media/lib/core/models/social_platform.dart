enum SocialPlatform {
  instagram,
  twitter,
  facebook,
  tiktok;

  String get displayName => switch (this) {
        SocialPlatform.instagram => 'Instagram',
        SocialPlatform.twitter => 'Twitter / X',
        SocialPlatform.facebook => 'Facebook',
        SocialPlatform.tiktok => 'TikTok',
      };

  bool get isActive => this == SocialPlatform.instagram;

  static SocialPlatform fromString(String value) =>
      SocialPlatform.values.firstWhere(
        (e) => e.name == value,
        orElse: () => SocialPlatform.instagram,
      );
}
