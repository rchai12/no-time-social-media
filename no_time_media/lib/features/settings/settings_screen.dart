import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/providers/settings_provider.dart';
import 'package:no_time_media/core/providers/subscription_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final _privacyUrl = Uri.parse('https://example.com/privacy');
  static final _termsUrl = Uri.parse('https://example.com/terms');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(photoCountProvider);
    final subscription = ref.watch(subscriptionProvider);

    return ListView(
      children: [
        const _SectionHeader('Scanning'),
        ListTile(
          title: const Text('Photos to scan'),
          subtitle: Text('$count photos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPhotoCountSheet(context, ref),
        ),
        const Divider(),
        const _SectionHeader('Subscription'),
        subscription.when(
          data: (isPro) => isPro
              ? const ListTile(
                  leading: Icon(Icons.star, color: Color(0xFFFFD700)),
                  title: Text('Pro Plan'),
                  subtitle: Text('20 generations per day'),
                  trailing: Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Free Plan'),
                  subtitle: const Text('3 generations per month'),
                  trailing: ElevatedButton(
                    onPressed: () => context.push('/paywall'),
                    child: const Text('Upgrade'),
                  ),
                ),
          loading: () => const ListTile(
            leading: Icon(Icons.star_outline),
            title: Text('Subscription'),
            subtitle: Text('Checking…'),
          ),
          error: (_, _) => ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Free Plan'),
            subtitle: const Text('3 generations per month'),
            trailing: ElevatedButton(
              onPressed: () => context.push('/paywall'),
              child: const Text('Upgrade'),
            ),
          ),
        ),
        const Divider(),
        const _SectionHeader('Account'),
        ListTile(
          title: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            try {
              await Purchases.logOut();
            } catch (_) {
              // RevenueCat may be unconfigured in local/dev builds.
            }
          },
        ),
        const Divider(),
        const _SectionHeader('Legal'),
        ListTile(
          title: const Text('Privacy Policy'),
          onTap: () => _openPlaceholder(context, _privacyUrl),
        ),
        ListTile(
          title: const Text('Terms of Service'),
          onTap: () => _openPlaceholder(context, _termsUrl),
        ),
      ],
    );
  }

  Future<void> _openPlaceholder(BuildContext context, Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Legal pages will be added before launch')),
      );
    }
  }

  Future<void> _openPhotoCountSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => _PhotoCountSheet(
        initialCount: ref.read(photoCountProvider),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PhotoCountSheet extends ConsumerStatefulWidget {
  const _PhotoCountSheet({required this.initialCount});

  final int initialCount;

  @override
  ConsumerState<_PhotoCountSheet> createState() => _PhotoCountSheetState();
}

class _PhotoCountSheetState extends ConsumerState<_PhotoCountSheet> {
  late double _value = widget.initialCount.toDouble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'How many photos should the app scan?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Slider(
            min: 10,
            max: 50,
            divisions: 8,
            label: '${_value.round()}',
            value: _value,
            onChanged: (value) => setState(() => _value = value),
          ),
          Text('Scanning ${_value.round()} photos'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await ref
                    .read(photoCountProvider.notifier)
                    .setCount(_value.round());
                ref.invalidate(photoScanProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
