import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Proves the native libmpv libs link on every platform at startup — the only
  // media_kit assertion the scaffold makes. The player itself lands in Task 1.4.
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: AuroraApp()));
}
