import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'overlay_bridge.dart';
import 'state.dart';
import 'why_data_modal.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final overlay = ref.watch(overlayPermissionGrantedProvider);
    final vpn = ref.watch(vpnPermissionGrantedProvider);
    final access = ref.watch(accessibilityPermissionGrantedProvider);
    final shots = ref.watch(screenshotPermissionGrantedProvider);
    final mic = ref.watch(microphonePermissionGrantedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.permissionsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PermissionTile(
            title: strings.permOverlayTitle,
            reason: strings.permOverlayReason,
            granted: overlay,
            onTap: () async {
              await showWhyDataDialog(
                context,
                title: strings.permOverlayTitle,
                reason: strings.permOverlayReason,
              );
              final ok = await OverlayBridge.ensureOverlayEnabled();
              if (ok) {
                ref
                    .read(overlayPermissionGrantedProvider.notifier)
                    .state = true;
                ref.read(floatingEnabledProvider.notifier).state = true;
              }
            },
          ),
          _PermissionTile(
            title: strings.permVpnTitle,
            reason: strings.permVpnReason,
            granted: vpn,
            onTap: () async {
              await showWhyDataDialog(
                context,
                title: strings.permVpnTitle,
                reason: strings.permVpnReason,
              );
              ref.read(vpnPermissionGrantedProvider.notifier).state = true;
            },
          ),
          _PermissionTile(
            title: strings.permAccessTitle,
            reason: strings.permAccessReason,
            granted: access,
            onTap: () async {
              await showWhyDataDialog(
                context,
                title: strings.permAccessTitle,
                reason: strings.permAccessReason,
              );
              ref
                  .read(accessibilityPermissionGrantedProvider.notifier)
                  .state = true;
            },
          ),
          _PermissionTile(
            title: strings.permScreenshotTitle,
            reason: strings.permScreenshotReason,
            granted: shots,
            onTap: () async {
              await showWhyDataDialog(
                context,
                title: strings.permScreenshotTitle,
                reason: strings.permScreenshotReason,
              );
              ref
                  .read(screenshotPermissionGrantedProvider.notifier)
                  .state = true;
            },
          ),
          _PermissionTile(
            title: strings.permMicTitle,
            reason: strings.permMicReason,
            granted: mic,
            onTap: () async {
              await showWhyDataDialog(
                context,
                title: strings.permMicTitle,
                reason: strings.permMicReason,
              );
              ref
                  .read(microphonePermissionGrantedProvider.notifier)
                  .state = true;
            },
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.reason,
    required this.granted,
    required this.onTap,
  });

  final String title;
  final String reason;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      title: Text(title),
      subtitle: Text(reason),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120, minHeight: 44),
        child: ElevatedButton(
          onPressed: granted ? null : onTap,
          child: Text(granted ? 'Granted' : 'Review'),
        ),
      ),
    );
  }
}
