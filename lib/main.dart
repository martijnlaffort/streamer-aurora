import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cap total decoded-image memory. Each image is already decode-size-capped at
  // its widget, but this bounds the sum so a fast scroll through many posters
  // can't push a memory-constrained (sideloaded) iOS build past the OS's
  // per-app limit — which showed up as the app suddenly quitting mid-browse.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB
  // Proves the native libmpv libs link on every platform at startup — the only
  // media_kit assertion the scaffold makes. The player itself lands in Task 1.4.
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: AuroraApp()));
}
