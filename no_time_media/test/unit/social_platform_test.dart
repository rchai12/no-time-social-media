import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/core/models/social_platform.dart';

void main() {
  group('SocialPlatform', () {
    test('instagram is the only active platform', () {
      expect(SocialPlatform.instagram.isActive, isTrue);
      expect(SocialPlatform.twitter.isActive, isFalse);
      expect(SocialPlatform.facebook.isActive, isFalse);
      expect(SocialPlatform.tiktok.isActive, isFalse);
    });

    test('displayName matches spec labels', () {
      expect(SocialPlatform.instagram.displayName, 'Instagram');
      expect(SocialPlatform.twitter.displayName, 'Twitter / X');
      expect(SocialPlatform.facebook.displayName, 'Facebook');
      expect(SocialPlatform.tiktok.displayName, 'TikTok');
    });

    test('fromString parses known names and defaults to instagram', () {
      expect(SocialPlatform.fromString('instagram'), SocialPlatform.instagram);
      expect(SocialPlatform.fromString('twitter'), SocialPlatform.twitter);
      expect(SocialPlatform.fromString('unknown'), SocialPlatform.instagram);
    });
  });
}
