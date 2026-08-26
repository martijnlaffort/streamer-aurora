import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20; // 64 MB
  // Proves the native libmpv libs link on every platform at startup — the only
  // media_kit assertion the scaffold makes. The player itself lands in Task 1.4.
  MediaKit.ensureInitialized();
  _registerFontLicenses();
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
