import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_files_repository.dart' show localFileId;
import 'local_media_platform.dart';

/// Marks a playlist stored inside the app, relative to its support directory.
///
/// Relative on purpose. iOS moves an app's container to a new path on some
/// updates, so an absolute path saved today can point at nothing next month,
/// and the account id (derived from this string) would change with it.
const kAppFilePrefix = 'dawn-file:';

bool isAppFile(String location) => location.startsWith(kAppFilePrefix);

/// The file behind a [kAppFilePrefix] location.
Future<File> appFileFor(String location,
    {Future<Directory> Function() base = getApplicationSupportDirectory}) async {
  final relative = location.substring(kAppFilePrefix.length);
  return File('${(await base()).path}/$relative');
}

/// Copies a picked or opened playlist into the app's own storage and returns
/// its [kAppFilePrefix] location, ready to use as the playlist address.
///
/// A copy, not a reference: the playlist is re-read on every refresh, long
/// after the picker's access to the original has lapsed.
Future<String> importPlaylistFile(LocalMediaPick pick,
    {Future<Directory> Function() base = getApplicationSupportDirectory}) async {
  final dir = Directory('${(await base()).path}/playlists');
  await dir.create(recursive: true);
  final safeName = pick.name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
  // Prefixed with the file's identity so two different "playlist.m3u" files do
  // not overwrite each other, while the same file imported twice lands on the
  // same name (and so the same account).
  final id = localFileId(name: pick.name, sizeBytes: pick.sizeBytes);
  final fileName = '${id.substring(0, 8)}-$safeName';
  await File(pick.path).copy('${dir.path}/$fileName');
  return '${kAppFilePrefix}playlists/$fileName';
}

/// The name to show for a playlist location: the file name for one stored in
/// the app, otherwise the location itself.
String playlistDisplayName(String location) {
  if (!isAppFile(location)) return location;
  final name = location.split('/').last;
  final dash = name.indexOf('-');
  return dash == -1 ? name : name.substring(dash + 1);
}
