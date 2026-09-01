import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'tour/screenshot_tour.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cap total decoded-image memory. Each image is already decode-size-capped at
  // its widget, but this bounds the sum so a fast scroll through many posters
  // can't push a memory-constrained (sideloaded) iOS build past the OS's
  // per-app limit — which showed up as the app suddenly quitting mid-browse.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20; // 64 MB
  // Proves the native libmpv libs link on every platform at startup — the only
  // media_kit assertion the scaffold makes. The player itself lands in Task 1.4.
  MediaKit.ensureInitialized();
  _registerFontLicenses();

  // A screenshot build drives itself (see lib/tour/screenshot_tour.dart). It
  // needs a handle on the providers from outside the widget tree, so the
  // container is built here rather than by ProviderScope. `screenshotTourEnabled`
  // is a const false in every normal build, so this branch and the tour with it
  // are compiled out.
  if (screenshotTourEnabled) {
    final container = ProviderContainer();
    runApp(UncontrolledProviderScope(
      container: container,
      child: const DawnPlayerApp(),
    ));
    unawaited(runScreenshotTour(container));
    return;
  }

  runApp(const ProviderScope(child: DawnPlayerApp()));
}

/// Inter and Outfit are bundled as assets, and the SIL Open Font License they
/// ship under requires the licence to be distributed with them. Registering
/// here puts both texts in Flutter's own licence page, which is where anyone
/// looking for them will look.
///
/// [LicenseRegistry] takes a lazy stream, so the files are only read if that
/// page is actually opened — this costs nothing at startup.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final font in const ['Inter', 'Outfit']) {
      final text =
          await rootBundle.loadString('assets/licenses/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}
