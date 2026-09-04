import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/db/app_database.dart' show OverrideScope;
import '../../../data/providers.dart';
import '../../../data/repositories/catalog_overrides_repository.dart';
import '../../../domain/models/models.dart';
import '../live_providers.dart';

/// Which channels the guide has nothing for, and a way to fix them.
///
/// The empty grid row is the most-repeated complaint in this whole category,
/// and it has several causes that all look identical: an id the XMLTV feed
/// does not carry, a feed that simply omits the channel, a name that matched
/// nothing. Naming the number and listing the channels turns a silent defect
/// into a task; the mapping below is how it gets finished.
class GuideCoverageScreen extends ConsumerWidget {
  const GuideCoverageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(guideCoverageProvider).value;
    final missing = ref.watch(channelsWithoutEpgProvider);
    final overrides =
        ref.watch(catalogOverridesProvider).value ?? CatalogOverrides.empty;

    return Scaffold(
      appBar: AppBar(title: const Text('Guide coverage')),
      body: Column(
        children: [
          if (coverage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${coverage.covered} of ${coverage.total} channels have '
                    'guide data',
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    coverage.total == coverage.covered
                        ? 'Every channel is matched to the guide.'
                        : '${coverage.total - coverage.covered} have none. '
                            'That is usually the playlist and the guide '
                            'disagreeing about a channel\'s id, not a missing '
                            'programme — pick the matching guide entry below '
                            'and it will fill in.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: missing.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e', style: TextStyle(color: AppColors.error))),
              data: (channels) {
                if (channels.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nothing to fix — every channel is matched.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final channel = channels[i];
                    final mapped = overrides.epgIds[channel.id];
                    return ListTile(
                      autofocus: i == 0,
                      title: Text(channel.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        mapped == null
                            ? 'Playlist id: ${channel.epgChannelId ?? channel.id}'
                            : 'Mapped to $mapped',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: mapped == null
                                ? AppColors.textSecondary
                                : AppColors.accent),
                      ),
                      trailing: mapped == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: 'Clear mapping',
                              icon: const Icon(Icons.close),
                              onPressed: () => _map(ref, channel, null),
                            ),
                      onTap: () => _pick(context, ref, channel),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _map(WidgetRef ref, Channel channel, String? epgId) async {
    final account = await ref.read(activeAccountProvider.future);
    if (account == null) return;
    await ref.read(catalogOverridesRepositoryProvider).setName(
          accountId: account.id,
          scope: OverrideScope.epg,
          targetId: channel.id,
          name: epgId,
        );
    ref.invalidate(catalogOverridesProvider);
    ref.invalidate(guideProvider);
  }

  /// Picks the guide entry this channel should read from.
  ///
  /// Filterable, because a real XMLTV feed carries thousands of ids and
  /// scrolling to `uk.bbc.one` past all of them is not a fix, it is a chore.
  Future<void> _pick(
      BuildContext context, WidgetRef ref, Channel channel) async {
    final keys = await ref.read(knownEpgKeysProvider.future);
    if (!context.mounted) return;
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No guide data loaded yet — open the TV Guide first.')));
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: _KeyPicker(channel: channel, keys: keys),
        ),
      ),
    );
    if (chosen != null) await _map(ref, channel, chosen);
  }
}

class _KeyPicker extends StatefulWidget {
  const _KeyPicker({required this.channel, required this.keys});

  final Channel channel;
  final List<String> keys;

  @override
  State<_KeyPicker> createState() => _KeyPickerState();
}

class _KeyPickerState extends State<_KeyPicker> {
  late List<String> _shown = widget.keys;
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seed the filter with the channel's own name: the matching guide id
    // usually contains it, so the answer is normally the first row.
    _filter.text = widget.channel.displayName
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .take(1)
        .join();
    _apply(_filter.text);
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _apply(String term) {
    final t = term.trim().toLowerCase();
    setState(() => _shown = t.isEmpty
        ? widget.keys
        : [for (final k in widget.keys) if (k.toLowerCase().contains(t)) k]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guide entry for ${widget.channel.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title),
              const SizedBox(height: 10),
              TextField(
                controller: _filter,
                autocorrect: false,
                onChanged: _apply,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _shown.isEmpty
              ? Center(
                  child: Text('No guide ids match that.',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _shown.length,
                  itemBuilder: (context, i) => ListTile(
                    autofocus: i == 0,
                    dense: true,
                    title: Text(_shown[i],
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, _shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
