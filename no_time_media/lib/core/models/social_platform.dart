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

  static SocialPlatform fromString(String value) {
    final normalized = value.trim().toLowerCase();
    return SocialPlatform.values.firstWhere(
      (platform) => platform.name == normalized,
      orElse: () => SocialPlatform.instagram,
    );
  }
}
