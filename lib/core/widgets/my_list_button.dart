import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../features/home/home_providers.dart' show myListProvider;
import '../../features/movies/movies_providers.dart' show isFavoriteProvider;

/// Add/remove a title from My List, for the movie and series detail pages.
///
/// Labelled rather than a bare heart: My List is named that everywhere else
/// (the Home rail, the hero button), and an unlabelled heart does not read as
/// "this is the list on my home screen".
///
/// Imports two feature providers, which is the wrong direction for `core/`.
/// The alternative was a third copy of this toggle; the coupling is one line
/// and there is no cycle, since neither provider file imports widgets.
class MyListButton extends ConsumerWidget {
  const MyListButton({super.key, required this.contentKey});

  /// `account:movie:id` or `account:series:id` — see contentKeyForSeries.
  final String contentKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isFavoriteProvider(contentKey)).value ?? false;
    return FilledButton.tonalIcon(
      onPressed: () async {
        await ref.read(favoritesRepositoryProvider).toggle(contentKey);
        ref.invalidate(isFavoriteProvider(contentKey));
        // Home's rail reads favourites, so it has to be told they changed.
        ref.invalidate(myListProvider);
      },
      icon: Icon(saved ? Icons.check : Icons.add, size: 18),
      label: Text(saved ? 'Added' : 'My List'),
    );
  }
}
