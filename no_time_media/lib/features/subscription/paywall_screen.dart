import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:no_time_media/core/providers/generation_provider.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';
import 'package:no_time_media/core/services/subscription_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      final photos = ref.read(photoScanProvider).value ?? [];
      context.pop();
      if (photos.isNotEmpty) {
        await ref.read(generationProvider.notifier).generatePosts(photos);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Purchase failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock Pro'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.auto_awesome, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Unlock No Time Media Pro',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const _FeatureRow(text: '20 AI post drafts / day'),
                const _FeatureRow(text: 'Priority AI processing'),
                const _FeatureRow(text: 'Instagram-optimized captions'),
                const SizedBox(height: 24),
                const Text(
                  '\$7.99 / month',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(SubscriptionService.purchase),
                    child: const Text('Start Pro Subscription'),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(SubscriptionService.restorePurchases),
                  child: const Text('Restore Purchases'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text('Not now'),
                ),
                const Spacer(),
                const Text(
                  'Payment charged to your App Store / Google Play account on confirmation. '
                  'Subscription renews automatically unless cancelled 24 hours before the '
                  'end of the current period.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
