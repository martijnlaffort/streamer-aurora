import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

/// What a pairing QR carries: the code, and the backend the television opened
/// its session on.
typedef PairScan = ({String code, String? backend});

/// Reads the television's pairing QR with the phone's camera.
///
/// Typing a six-character code across a room is the one step pairing still
/// asked for; this removes it. The code path stays: a phone without a camera,
/// or a user who would rather type, loses nothing.
///
/// Returns via `Navigator.pop` so the caller's existing send flow runs
/// unchanged with the scanned values.
class PairScanScreen extends StatefulWidget {
  const PairScanScreen({super.key});

  /// The URI a television renders. Kept as a scheme URL rather than the bare
  /// code so a stranger's QR scanner shows something self-describing, and so a
  /// future deep link can open the app straight into pairing.
  static String uriFor({required String code, required String backend}) =>
      Uri(
        scheme: 'dawnplayer',
        host: 'pair',
        queryParameters: {'code': code, 'backend': backend},
      ).toString();

  /// Parses a scanned value: our URI, or a bare code someone printed.
  static PairScan? parse(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    if (uri != null && uri.scheme == 'dawnplayer' && uri.host == 'pair') {
      final code = uri.queryParameters['code']?.trim().toUpperCase();
      if (code == null || code.isEmpty) return null;
      final backend = uri.queryParameters['backend']?.trim();
      return (code: code, backend: (backend?.isEmpty ?? true) ? null : backend);
    }
    final bare = RegExp(r'^[A-Za-z0-9]{4,12}$');
    if (bare.hasMatch(text)) return (code: text.toUpperCase(), backend: null);
    return null;
  }

  @override
  State<PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends State<PairScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final parsed = PairScanScreen.parse(code.rawValue ?? '');
      if (parsed == null) continue;
      // First valid frame wins; the camera keeps delivering frames after the
      // pop is scheduled, and a second pop would tear down the wrong route.
      _handled = true;
      Navigator.of(context).pop(parsed);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan the TV\'s code'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'The camera is not available. Type the code instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          // A framing guide, so it reads as "point this at the square on the
          // television" rather than as a live camera feed with no purpose.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Text(
              'Point at the square on the television',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
