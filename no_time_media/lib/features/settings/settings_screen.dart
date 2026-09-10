import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/providers/photo_count_provider.dart';
import 'package:no_time_media/core/services/prefs_service.dart';
import 'package:no_time_media/core/services/subscription_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _draggingCount;
  late final Future<bool> _isProFuture = _subscriptionIsPro();

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    try {
      await Purchases.logOut();
    } catch (_) {
      // RevenueCat may be unconfigured in local/dev builds.
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(photoCountProvider);
    final sliderValue = (_draggingCount ?? count).toDouble();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const ListTile(
          title: Text('Photos to scan'),
          subtitle: Text('How many recent photos to score (10–50)'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${sliderValue.round()}'),
              Expanded(
                child: Slider(
                  min: PrefsService.minPhotoCount.toDouble(),
                  max: PrefsService.maxPhotoCount.toDouble(),
                  divisions: PrefsService.maxPhotoCount - PrefsService.minPhotoCount,
                  label: '${sliderValue.round()}',
                  value: sliderValue,
                  onChanged: (value) {
                    setState(() => _draggingCount = value.round());
                  },
                  onChangeEnd: (value) {
                    ref.read(photoCountProvider.notifier).setCount(value.round());
                    setState(() => _draggingCount = null);
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        FutureBuilder<bool>(
          future: _isProFuture,
          builder: (context, snapshot) {
            final isPro = snapshot.data == true;
            return ListTile(
              leading: Icon(isPro ? Icons.workspace_premium : Icons.person_outline),
              title: const Text('Subscription'),
              subtitle: Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Checking…'
                    : (isPro ? 'Pro' : 'Free'),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: _signOut,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          onTap: () => _openLegal(
            context,
            title: 'Privacy Policy',
            body:
                'No Time Media reads photos on your device to score them locally. '
                'Only 256×256 thumbnails of photos you choose to generate posts from '
                'are sent to our servers. Photos are never stored on our servers. '
                'Your account ID is used for sign-in and subscription management. '
                'Payments are processed by the App Store or Google Play via RevenueCat.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('Terms of Use'),
          onTap: () => _openLegal(
            context,
            title: 'Terms of Use',
            body:
                'Payment is charged to your App Store or Google Play account on confirmation. '
                'Subscriptions renew automatically unless cancelled at least 24 hours before '
                'the end of the current period. Manage or cancel in your store account settings. '
                'Free accounts may generate a limited number of AI posts per month. '
                'Pro accounts may generate up to 20 AI posts per day.',
          ),
        ),
      ],
    );
  }

  Future<bool> _subscriptionIsPro() async {
    try {
      return await SubscriptionService.isPro();
    } catch (_) {
      return false;
    }
  }

  void _openLegal(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(body, style: const TextStyle(fontSize: 16, height: 1.4)),
          ),
        ),
      ),
    );
  }
}
