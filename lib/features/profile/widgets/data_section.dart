import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/common.dart';
import '../../../providers/providers.dart';
import '../../../providers/refresh.dart';
import 'backup_actions.dart';
import 'cloud_account_dialog.dart';

class DataSection extends ConsumerWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncStatusProvider).value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Data'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export / back up data'),
            subtitle: const Text('JSON file with all workouts, programs and records'),
            onTap: () => exportBackup(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replaces all data on this device'),
            onTap: () => restoreBackup(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Cloud account'),
            subtitle: Text(sync == null
                ? 'Checking status...'
                : !sync.configured
                    ? 'Not configured'
                    : sync.signedIn
                        ? 'Signed in as ${sync.userEmail}'
                        : 'Sign in or create an account'),
            onTap: () async {
              final remote = ref.read(remoteGatewayProvider);
              if (!remote.isConfigured) {
                snack(context, 'Cloud sync is not configured for this build.');
                return;
              }
              await showDialog<bool>(
                context: context,
                builder: (_) => CloudAccountDialog(remote: remote),
              );
              ref.invalidate(syncStatusProvider);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(sync == null
                ? 'Sync now'
                : sync.configured
                    ? 'Sync now (${sync.pending} pending)'
                    : 'Cloud sync not configured'),
            subtitle: const Text('Workouts and programs are saved locally first.'),
            onTap: () async {
              if (!ref.read(remoteGatewayProvider).isConfigured) {
                snack(context, 'Cloud sync is not configured for this build.');
                return;
              }
              try {
                final n = await ref.read(syncServiceProvider).syncNow();
                refreshAll(ref);
                if (context.mounted) snack(context, 'Sync complete ($n changes).');
              } catch (e) {
                ref.invalidate(syncStatusProvider);
                if (context.mounted) snack(context, 'Sync failed: $e');
              }
            },
          ),
        ]),
      ),
    ]);
  }
}
