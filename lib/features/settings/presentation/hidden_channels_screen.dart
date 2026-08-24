import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/db/app_database.dart' show OverrideScope;
import '../../../data/providers.dart';

/// Channels the user hid, and the way back.
///
/// This screen is not optional polish: hiding a channel happens from a menu on
/// the channel itself, and once hidden that row is gone from every list — so
/// without somewhere to see the hidden set, the action would be one-way.
class HiddenChannelsScreen extends ConsumerWidget {
  const HiddenChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(_hiddenChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden channels'),
        actions: [
          if ((hidden.value ?? const []).isNotEmpty)
            TextButton(
              onPressed: () => _showAll(ref),
              child: const Text('Show all'),
            ),
        ],
      ),
      body: hidden.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
            error: e, onRetry: () => ref.invalidate(_hiddenChannelsProvider)),
        data: (channels) {
          if (channels.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing hidden. Hide a channel from the ⋮ menu next to it in '
                  'Live TV.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: channels.length,
            itemBuilder: (context, i) {
              final entry = channels[i];
              return ListTile(
                autofocus: i == 0,
                leading: Icon(Icons.visibility_off_outlined,
                    color: AppColors.textSecondary),
                title: Text(entry.name),
                trailing: TextButton(
                  onPressed: () => _unhide(ref, entry.id),
                  child: const Text('Show'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unhide(WidgetRef ref, String channelId) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).setHidden(
          accountId: account.id,
          scope: OverrideScope.channel,
          targetId: channelId,
          hidden: false,
        );
    ref.invalidate(catalogOverridesProvider);
  }

  Future<void> _showAll(WidgetRef ref) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    final overrides = await ref.read(catalogOverridesProvider.future);
    final repo = ref.read(catalogOverridesRepositoryProvider);
    for (final id in overrides.hiddenChannels) {
      await repo.setHidden(
        accountId: account.id,
        scope: OverrideScope.channel,
        targetId: id,
        hidden: false,
      );
    }
    ref.invalidate(catalogOverridesProvider);
  }
}

/// The hidden channels, resolved to something nameable.
///
/// A hidden id whose channel is no longer in the playlist still needs a row —
/// otherwise the override would be invisible AND un-removable — so those fall
/// back to showing the id.
final _hiddenChannelsProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final overrides = await ref.watch(catalogOverridesProvider.future);
  if (overrides.hiddenChannels.isEmpty) return const [];
  final catalog = ref.watch(catalogRepositoryProvider);
  final out = <({String id, String name})>[];
  for (final id in overrides.hiddenChannels) {
    final channel = await catalog.channelById(account, id);
    out.add((
      id: id,
      name: overrides.channelName(
          id, channel?.name ?? 'Channel no longer in this playlist ($id)'),
    ));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
});
