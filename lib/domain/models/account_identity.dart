import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'enums.dart';

/// Derives an account's id from *what the account actually is* — the playlist
/// it points at — rather than from when it happened to be added.
///
/// This matters far beyond tidiness, because the id is the first segment of
/// every content key (`account:type:id`, see `content_key.dart`), and content
/// keys are what watch progress, My List and the sync backend are stored
/// against.
///
/// Ids used to be `acc_<millisecondsSinceEpoch>`. Two consequences, both of
/// which were observed in the wild:
///
///  * **Sync could not work across devices.** Adding the same playlist on a
///    phone and on a TV minted two unrelated ids, so every row either device
///    pushed came back down under a prefix the other could not resolve, and was
///    silently discarded as "belongs to a different account".
///  * **Re-adding a playlist orphaned everything.** Same server, same login, new
///    timestamp, new id — and the entire watch history and My List were stranded
///    under the old prefix.
///
/// Deriving the id from the credentials fixes both at once: the same playlist
/// yields the same id on every device and on every re-add, so saving is
/// idempotent and sync has a shared namespace to meet in.
///
/// The value is a truncated SHA-256 of the identifying fields. 96 bits is far
/// past any collision concern for a handful of accounts, and it keeps the id
/// short enough to stay readable in a content key.
String stableAccountId({
  required AccountType type,
  required String serverUrl,
  required String username,
}) {
  final identity = [
    type.name,
    normalizeServerUrl(serverUrl),
    // NOT lowercased: Xtream usernames can be case-sensitive, and collapsing
    // two genuinely different logins into one id is a far worse failure than
    // failing to collapse one that was retyped in a different case.
    username.trim(),
  ].join('|');
  final digest = sha256.convert(utf8.encode(identity));
  return 'acc_${digest.toString().substring(0, 24)}';
}

/// Canonical form of a server URL, so that trivial typing differences do not
/// mint different accounts. `HTTP://Panel.example.com:80/` and
/// `http://panel.example.com` are the same panel and must hash alike.
///
/// The host is lowercased (DNS is case-insensitive), the port is made explicit
/// so `:80` and an omitted port agree, and trailing slashes go. The path is
/// otherwise preserved — some panels live under a subdirectory, and that is a
/// real difference.
String normalizeServerUrl(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    // Not parseable as a URL (or a bare hostname): fall back to a plain
    // case-and-slash normalisation rather than dropping the value entirely.
    return trimmed.toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme.toLowerCase();
  final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return '$scheme://${uri.host.toLowerCase()}:$port$path';
}
