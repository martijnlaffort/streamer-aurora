import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../domain/models/models.dart';
import '../../player/presentation/player_screen.dart' show kStreamUserAgent;
import '../live_providers.dart';

/// Two live channels side by side, with sound from one of them.
///
/// Deliberately capped at TWO. Every pane is its own libmpv instance and its own
/// hardware decoder: a pair of 1080p streams is comfortable on the hardware this
/// app runs on, four is not, and the failure mode of over-committing a decoder
/// is stutter in both panes rather than a clean error. Two is the number that
/// covers the actual use — two matches at once — without gambling.
///
/// Exactly one pane has audio at any moment. Two live streams talking over each
/// other is not a feature, and muting is instant while stopping a stream is not,
/// so the quiet pane keeps decoding and can be switched to without a re-buffer.
class MultiViewScreen extends ConsumerStatefulWidget {
  const MultiViewScreen({super.key, required this.channels});

  final List<Channel> channels;

  @override
  ConsumerState<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends ConsumerState<MultiViewScreen> {
  /// Index of the pane you can hear.
  int _audioPane = 0;

  /// Fullscreen and the orientation lock are a phone/tablet concern; on desktop
  /// these calls can pin the window to a broken size, and a TV has no
  /// orientation to lock.
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    // Landscape and full-bleed: two 16:9 panes side by side make no sense in
    // portrait, and the chrome would eat the little height there is.
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panes = widget.channels.take(2).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (final (i, channel) in panes.indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _MultiPane(
                        key: ValueKey(channel.id),
                        channel: channel,
                        hasAudio: i == _audioPane,
                        onSelected: () => setState(() => _audioPane = i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sound: ${panes.isEmpty ? '—' : panes[_audioPane].name}',
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 16),
                  FilledButton.tonalIcon(
                    autofocus: true,
                    onPressed: panes.length < 2
                        ? null
                        : () => setState(
                            () => _audioPane = _audioPane == 0 ? 1 : 0),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: const Text('Swap sound'),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choose the channel to watch alongside [besides].
///
/// Favourites first, then the rest alphabetically and capped — this is a picker,
/// not a browser, and a 25k-channel list would be neither. Returns null if the
/// user backs out.
Future<Channel?> pickCompanionChannel(
    BuildContext context, Channel besides) async {
  return showModalBottomSheet<Channel>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: _CompanionPicker(besides: besides),
      ),
    ),
  );
}

class _CompanionPicker extends ConsumerWidget {
  const _CompanionPicker({required this.besides});

  final Channel besides;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(_companionOptionsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Watch alongside ${besides.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title),
          ),
        ),
        Expanded(
          child: options.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('$e', style: TextStyle(color: AppColors.error))),
            data: (list) {
              final choices = [
                for (final c in list)
                  if (c.id != besides.id) c,
              ];
              if (choices.isEmpty) {
                return Center(
                  child: Text('No other channels available.',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                itemCount: choices.length,
                itemBuilder: (context, i) => ListTile(
                  autofocus: i == 0,
                  leading: Icon(Icons.live_tv, color: AppColors.textSecondary),
                  title: Text(choices[i].name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, choices[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Favourites, then the start of the alphabetical list. Capped: the picker only
/// has to offer a plausible companion, not the whole catalogue.
final _companionOptionsProvider = FutureProvider<List<Channel>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final overrides = await ref.watch(catalogOverridesProvider.future);
  final favourites = await ref.watch(favoriteChannelsProvider.future);
  final rest = await ref.watch(catalogRepositoryProvider).channels(
        account,
        excludeIds: overrides.hiddenChannels,
        byName: true,
        groupVariants: ref.watch(groupChannelVariantsProvider),
        limit: 200,
      );
  final seen = <String>{};
  return [
    for (final c in [...favourites, ...rest])
      if (seen.add(c.id)) c,
  ];
});

/// One pane: its own player, its own decoder, its own failure.
class _MultiPane extends ConsumerStatefulWidget {
  const _MultiPane({
    super.key,
    required this.channel,
    required this.hasAudio,
    required this.onSelected,
  });

  final Channel channel;
  final bool hasAudio;
  final VoidCallback onSelected;

  @override
  ConsumerState<_MultiPane> createState() => _MultiPaneState();
}

class _MultiPaneState extends ConsumerState<_MultiPane> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void didUpdateWidget(_MultiPane old) {
    super.didUpdateWidget(old);
    // Muting rather than pausing: the quiet pane keeps decoding, so swapping
    // sound is instant instead of costing a re-buffer.
    if (widget.hasAudio != old.hasAudio) _applyVolume();
  }

  void _applyVolume() => _player.setVolume(widget.hasAudio ? 100 : 0);

  Future<void> _open() async {
    try {
      final account = await ref.read(activeAccountProvider.future);
      if (!mounted || account == null) return;
      final url = await ref.read(sourceFactoryProvider)(account).buildStreamUrl(
            StreamRef(
              accountId: widget.channel.accountId,
              type: StreamType.live,
              streamId: widget.channel.id,
            ),
          );
      if (!mounted) return;
      final platform = _player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty(
            'user-agent', account.userAgent ?? kStreamUserAgent);
        // No timeshift buffer here: two disk-backed caches is a lot of writing
        // for panes nobody rewinds, and the point of this screen is watching
        // both edges live.
        await platform.setProperty('cache', 'no');
      }
      if (!mounted) return;
      _applyVolume();
      await _player.open(Media(url));
    } on Object catch (e) {
      // One pane failing must not take the other down with it.
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onSelected,
      onFocusChange: (focused) {
        if (focused) widget.onSelected();
      },
      focusColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        foregroundDecoration: BoxDecoration(
          // The pane you can hear is the one that is outlined — with two silent
          // pictures side by side there is otherwise nothing to say which is
          // which.
          border: Border.all(
            color: widget.hasAudio ? AppColors.accent : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_error != null)
              ColoredBox(
                color: AppColors.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Could not play ${widget.channel.name}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              Video(
                controller: _controller,
                controls: NoVideoControls,
                fill: Colors.black,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.scrim),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      if (widget.hasAudio)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.volume_up,
                              size: 16, color: AppColors.accent),
                        ),
                      Expanded(
                        child: Text(
                          widget.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
