import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Variety for rails that would otherwise show the same titles forever.
///
/// Most rails take the first N of an ordered set, so a catalogue that changes
/// slowly looks frozen: the same Award Winners, the same first slice of every
/// category, every single time. These helpers pick a *different* slice per
/// session instead.
///
/// The seed is deliberately per-launch rather than per-rebuild. Rails must not
/// reshuffle while you are scrolling, or when a provider happens to recompute —
/// content moving under your thumb is worse than content being stale. Invalidate
/// this provider to deal a new hand (pull-to-refresh does).
final rotationSeedProvider =
    Provider<int>((ref) => DateTime.now().millisecondsSinceEpoch);

/// [take] items from [items], chosen by [seed]. Returns everything (in order)
/// when there is nothing to choose from, so short rails keep their ranking.
List<T> rotatedSample<T>(List<T> items,
    {required int seed, required int take, Object? salt}) {
  if (items.length <= take) return items;
  final copy = [...items]..shuffle(Random(seed ^ (salt?.hashCode ?? 0)));
  return copy.take(take).toList();
}

/// Which page of [pages] to show this session.
///
/// [salt] keeps rails out of lockstep — without it every category turns the
/// page together, which reads as one big change rather than a fresh mix.
///
/// The seed is **hashed**, not used arithmetically. An earlier version did
/// `(seed ~/ 1000 + salt) % pages`, which fails badly: the seed is a clock, so
/// two launches N seconds apart shift every rail by the same N, and whenever N
/// divides [pages] *nothing* moves. Two launches two minutes apart produced a
/// byte-identical screen. Hashing decorrelates both the launches and the rails.
int rotatingPage({required int seed, required int pages, Object? salt}) {
  if (pages <= 1) return 0;
  return Random(seed ^ (salt?.hashCode ?? 0)).nextInt(pages);
}
