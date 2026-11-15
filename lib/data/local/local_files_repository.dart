import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../domain/models/models.dart';
import 'local_media_platform.dart';

/// The pseudo account id that files on this device live under.
///
/// Watch progress, resume and Continue Watching are all keyed
/// `account:type:id`, so a file gets the same treatment as a film from a
/// playlist by having an "account" of its own. Real account ids are sha256 hex
/// (see `stableAccountId`), so this can never collide with one.
const kLocalAccountId = 'local';

bool isLocalStream(StreamRef ref) => ref.accountId == kLocalAccountId;

/// Stable id for a file: its name and size, not its path.
///
/// The path is the wrong identity. The same film opened once from Files and
/// once from another app's share sheet arrives under two different paths (the
/// second is a copy in the app's Inbox), and a security-scoped bookmark is
/// different bytes every time it is made. Name + size is the same file to a
/// person, so it is the same file here — and its resume point follows it.
String localFileId({required String name, int? sizeBytes}) {
  final digest = sha256.convert(utf8.encode('$name|${sizeBytes ?? ''}'));
  return digest.toString().substring(0, 20);
}

/// One file the user has opened, remembered so it can be resumed.
class LocalFile {
  const LocalFile({
    required this.id,
    required this.name,
    required this.ref,
    required this.openedAt,
    this.sizeBytes,
    this.subtitlePath,
    this.subtitleName,
  });

  final String id;
  final String name;

  /// See [LocalMediaPick.ref].
  final String ref;
  final int? sizeBytes;

  /// UTC.
  final DateTime openedAt;

  /// A subtitle file the user attached, as a private copy in app storage.
  final String? subtitlePath;
  final String? subtitleName;

  /// The name without its extension, for titles: `Holiday 2024`.
  String get title {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String? get extension {
    final dot = name.lastIndexOf('.');
    return dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toLowerCase()
        : null;
  }

  StreamRef get streamRef => StreamRef(
        accountId: kLocalAccountId,
        type: StreamType.movie,
        streamId: id,
        containerExt: extension,
      );

  String get contentKey => contentKeyFor(
      accountId: kLocalAccountId, type: StreamType.movie, id: id);

  LocalFile copyWith({
    String? ref,
    int? sizeBytes,
    DateTime? openedAt,
    String? subtitlePath,
    String? subtitleName,
    bool clearSubtitle = false,
  }) =>
      LocalFile(
        id: id,
        name: name,
        ref: ref ?? this.ref,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        openedAt: openedAt ?? this.openedAt,
        subtitlePath: clearSubtitle ? null : (subtitlePath ?? this.subtitlePath),
        subtitleName: clearSubtitle ? null : (subtitleName ?? this.subtitleName),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'ref': ref,
        'size': sizeBytes,
        'openedAt': openedAt.millisecondsSinceEpoch,
        'subtitlePath': subtitlePath,
        'subtitleName': subtitleName,
      };

  static LocalFile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final ref = raw['ref'];
    final openedAt = raw['openedAt'];
    if (id is! String || name is! String || ref is! String || openedAt is! int) {
      return null;
    }
    final size = raw['size'];
    final subtitlePath = raw['subtitlePath'];
    final subtitleName = raw['subtitleName'];
    return LocalFile(
      id: id,
      name: name,
      ref: ref,
      sizeBytes: size is int ? size : null,
      openedAt: DateTime.fromMillisecondsSinceEpoch(openedAt, isUtc: true),
      subtitlePath: subtitlePath is String ? subtitlePath : null,
      subtitleName: subtitleName is String ? subtitleName : null,
    );
  }
}

/// The files the user has opened on this device, most recent first.
///
/// A small JSON file rather than a drift table: it is a short, device-local
/// list (never synced — a bookmark means nothing on another device), and a
/// table would be a schema migration for something that holds a few dozen
/// rows. Progress itself is NOT stored here; it lives in the same watch
/// progress table as everything else, under [LocalFile.contentKey].
class LocalFilesRepository {
  LocalFilesRepository({
    required this._directory,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  /// Old entries fall off the end. Their progress rows stay, harmlessly, and
  /// come back to life if the same file is opened again.
  static const maxEntries = 100;

  static const _fileName = 'local_files.json';

  List<LocalFile>? _cache;

  /// Serialises writes, so two quick opens cannot interleave read-modify-write.
  Future<void> _lock = Future.value();

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<List<LocalFile>> all() async {
    final cached = _cache;
    if (cached != null) return List.unmodifiable(cached);
    final file = await _file();
    var entries = <LocalFile>[];
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          entries = decoded.map(LocalFile.fromJson).whereType<LocalFile>().toList();
        }
      } on FormatException {
        // A half-written file from a crash. Losing the recent list is better
        // than refusing to start; progress is stored elsewhere and survives.
        entries = [];
      }
    }
    entries.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    _cache = entries;
    return List.unmodifiable(entries);
  }

  Future<LocalFile?> byId(String id) async {
    for (final f in await all()) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Records [pick] as just opened and returns its entry. Opening a file that
  /// is already known keeps its attached subtitle and refreshes its ref.
  Future<LocalFile> recordOpened(LocalMediaPick pick) => _mutate((entries) {
        final id = localFileId(name: pick.name, sizeBytes: pick.sizeBytes);
        final at = entries.indexWhere((f) => f.id == id);
        final now = _clock();
        final entry = at == -1
            ? LocalFile(
                id: id,
                name: pick.name,
                ref: pick.ref,
                sizeBytes: pick.sizeBytes,
                openedAt: now,
              )
            : entries[at].copyWith(
                ref: pick.ref, sizeBytes: pick.sizeBytes, openedAt: now);
        if (at != -1) entries.removeAt(at);
        entries.insert(0, entry);
        if (entries.length > maxEntries) {
          entries.removeRange(maxEntries, entries.length);
        }
        return entry;
      });

  /// Remembers [path] as [id]'s subtitle file, so it loads with the video
  /// every time. Null clears it.
  Future<void> setSubtitle(String id, {String? path, String? name}) =>
      _mutate<void>((entries) {
        final at = entries.indexWhere((f) => f.id == id);
        if (at == -1) return;
        entries[at] = path == null
            ? entries[at].copyWith(clearSubtitle: true)
            : entries[at].copyWith(subtitlePath: path, subtitleName: name);
      });

  Future<void> remove(String id) => _mutate<void>((entries) {
        entries.removeWhere((f) => f.id == id);
      });

  Future<T> _mutate<T>(T Function(List<LocalFile> entries) change) {
    final result = _lock.then((_) async {
      final entries = [...await all()];
      final value = change(entries);
      _cache = entries;
      final file = await _file();
      await file.parent.create(recursive: true);
      // Written beside and renamed over, so a crash mid-write leaves the old
      // list rather than half a new one.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
          jsonEncode([for (final f in entries) f.toJson()]),
          flush: true);
      await tmp.rename(file.path);
      return value;
    });
    _lock = result.then((_) {}, onError: (_) {});
    return result;
  }
}
