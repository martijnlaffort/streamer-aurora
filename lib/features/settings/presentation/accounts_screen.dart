import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';

/// Saved playlist accounts (PRD §8.1): list, switch the active one, delete,
/// and add new ones.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load accounts: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No accounts yet.'),
                  Text(
                    'Add an Xtream or M3U playlist to get started.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          final activeId = active.value?.id;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final account = list[i];
              final isActive = account.id == activeId;
              return Card(
                color: isActive ? AppColors.surfaceElevated : AppColors.surface,
                child: ListTile(
                  leading: Icon(
                    account.type == AccountType.xtream
                        ? Icons.dns_outlined
                        : Icons.playlist_play,
                    color: isActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                  title: Text(account.name),
                  subtitle: Text(
                    '${account.type.name} · ${_hostOf(account.serverUrl)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_circle,
                              color: AppColors.accent, size: 20),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.textSecondary),
                        onPressed: () => _confirmDelete(context, ref, account),
                      ),
                    ],
                  ),
                  onTap: isActive
                      ? null
                      : () async {
                          await ref
                              .read(accountRepositoryProvider)
                              .setActiveAccount(account.id);
                          ref.invalidate(activeAccountProvider);
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _hostOf(String url) => Uri.tryParse(url)?.host.isNotEmpty ?? false
      ? Uri.parse(url).host
      : url;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${account.name}"?'),
        content: const Text(
            'The cached catalog, watch progress, and favorites for this '
            'account will be removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(accountRepositoryProvider).deleteAccount(account.id);
    ref.invalidate(accountsProvider);
    ref.invalidate(activeAccountProvider);
  }
}
