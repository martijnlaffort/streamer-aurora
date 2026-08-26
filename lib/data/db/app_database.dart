import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/matching/channel_variant.dart';
import '../../domain/models/discovery.dart' show DiscoveryKind;
import '../../domain/models/enums.dart';

part 'app_database.g.dart';

// All timestamps are stored as explicit UTC epoch-milliseconds integers
// (`*MillisUtc`) rather than drift DateTime columns — DateTime columns round
// to seconds and rehydrate as local time, which is exactly the ambiguity the
// "store UTC end-to-end" rule exists to prevent. `mappers.dart` converts.

@DataClassName('AccountRow')
class AccountsTable extends Table {
  @override
  String get tableName => 'accounts';

  TextColumn get id => text()();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get name => text()();
  TextColumn get serverUrl => text()();
  TextColumn get username => text()();

  /// Optional XMLTV EPG url for M3U accounts.
  TextColumn get epgUrl => text().nullable()();
  IntColumn get createdAtMillisUtc => integer()();

  // Deliberately NO password column: credentials live in secure storage,
  // keyed by account id (global rule).

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get type => textEnum<CategoryType>()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {accountId, type, id};
}

@DataClassName('MovieRow')
class MoviesTable extends Table {
  @override
  String get tableName => 'movies';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get cast => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get containerExt => text().nullable()();
  IntColumn get addedAtMillisUtc => integer().nullable()();
  IntColumn get cachedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('SeriesRow')
class SeriesTable extends Table {
  @override
  String get tableName => 'series';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get plot => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get cast => text().nullable()();
  IntColumn get cachedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('EpisodeRow')
class EpisodesTable extends Table {
  @override
  String get tableName => 'episodes';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get seriesId => text()();
  IntColumn get seasonNumber => integer()();
  IntColumn get episodeNumber => integer()();
  TextColumn get title => text()();
  TextColumn get plot => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get stillUrl => text().nullable()();
  TextColumn get containerExt => text().nullable()();
  IntColumn get airDateMillisUtc => integer().nullable()();
  IntColumn get cachedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('ChannelRow')
class ChannelsTable extends Table {
  @override
  String get tableName => 'channels';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get epgChannelId => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();

  /// Whether the panel keeps a rolling recording of this channel, and for how
  /// many days (Xtream `tv_archive` / `tv_archive_duration`, schema v7).
  /// This is what makes "watch it from the start" possible for something that
  /// already aired.
  BoolColumn get tvArchive => boolean().withDefault(const Constant(false))();
  IntColumn get tvArchiveDays => integer().nullable()();
  IntColumn get cachedAtMillisUtc => integer()();

  /// Variant grouping (schema v13), all derived from [name] at write time by
  /// `parseChannelVariant` so the collapse can happen in SQL rather than after
  /// paging — grouping a page in Dart would hand the caller short pages.
  ///
  /// [variantKey] is what the rows a line ships for one channel share;
  /// [baseName] is the name without its quality tag (what a collapsed row
  /// shows); [qualityRank] decides which row the group plays.
  TextColumn get variantKey => text().nullable()();
  TextColumn get baseName => text().nullable()();
  IntColumn get qualityRank => integer().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

@DataClassName('WatchProgressRow')
class WatchProgressTable extends Table {
  @override
  String get tableName => 'watch_progress';

  /// `account:type:id` (see `contentKeyFor`).
  TextColumn get contentKey => text()();
  IntColumn get positionSeconds => integer()();
  IntColumn get durationSeconds => integer()();

  /// Last-write-wins key for the future sync backend (PRD §9).
  IntColumn get updatedAtMillisUtc => integer()();
  IntColumn get syncedAtMillisUtc => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// For an episode, the series it belongs to (added in v10). An episode
  /// content key cannot tell you its series, and the id only ever arrives in a
  /// sync payload — so it MUST be persisted. It used to be transient, which
  /// meant that if the one backfill attempt right after the pull failed or hit
  /// its cap, the series was never fetched again (the watermark had moved on,
  /// so the id never came back) and those episodes were missing from Continue
  /// Watching on that device forever. Stored, the backfill simply retries.
  TextColumn get seriesId => text().nullable()();

  @override
  Set<Column> get primaryKey => {contentKey};
}

@DataClassName('PreferencesRow')
class PreferencesTable extends Table {
  @override
  String get tableName => 'preferences';

  /// Single-row table; id is always [PreferencesRepository.singletonId].
  IntColumn get id => integer()();
  TextColumn get preferredAudioLang => text().nullable()();
  TextColumn get preferredSubtitleLang => text().nullable()();
  BoolColumn get autoplayNext => boolean().withDefault(const Constant(true))();

  /// Keep audio playing when the app is backgrounded (added in schema v2).
  BoolColumn get backgroundPlayback =>
      boolean().withDefault(const Constant(false))();

  /// Content-language filter: CSV of ContentLanguage codes to show, or null
  /// for "all languages" (added in schema v4).
  TextColumn get contentLanguages => text().nullable()();

  /// TMDB v3 API key for the discovery rails, or null when not configured —
  /// in which case only the bundled award rails appear (added in schema v6).
  /// Kept here rather than in secure storage deliberately: it is a personal
  /// read-only key for public list data, not a credential granting access to
  /// anything of the user's.
  TextColumn get tmdbApiKey => text().nullable()();

  /// ISO 3166-1 country for region-aware discovery ("what's popular/new *here*").
  /// Null → derived from the device locale (added in schema v6).
  TextColumn get discoveryRegion => text().nullable()();

  /// [AppThemeMode] name, or null for the dark default (added in schema v12).
  TextColumn get themeMode => text().nullable()();

  /// Text/poster size multiplier, 1.0 = as designed (added in schema v12).
  /// Device-local: it is not part of the sync payload, so sizing a phone does
  /// not resize the television.
  RealColumn get uiScale => real().nullable()();

  /// Collapse a line's per-quality duplicates into one channel (schema v13).
  /// Null → the on-by-default in [Preferences].
  BoolColumn get groupChannelVariants => boolean().nullable()();

  /// App state, not a user preference — which account the UI is showing.
  TextColumn get activeAccountId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's edits to what the panel sent: hidden, renamed and reordered
/// categories and channels (schema v11).
///
/// A real line ships hundreds of categories and tens of thousands of channels,
/// most of which a given household never wants to see. The panel decides the
/// names and the order; this table is how the user overrules that without
/// touching the cached catalogue itself — a refresh replaces catalogue rows
/// wholesale, so anything editable has to live beside them rather than in them.
@DataClassName('ReminderRow')
class RemindersTable extends Table {
  @override
  String get tableName => 'reminders';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get channelId => text()();
  TextColumn get channelName => text()();
  TextColumn get title => text()();
  IntColumn get startsAtMillisUtc => integer()();
  IntColumn get leadMinutes => integer().withDefault(const Constant(3))();
  IntColumn get notificationId => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CatalogOverrideRow')
class CatalogOverridesTable extends Table {
  @override
  String get tableName => 'catalog_overrides';

  TextColumn get accountId => text()();

  /// [OverrideScope] name — categories and channels have separate id spaces.
  TextColumn get scope => text()();
  TextColumn get targetId => text()();

  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Replacement display name; null keeps the panel's own.
  TextColumn get customName => text().nullable()();

  /// Position in the user's ordering; null sorts after everything explicitly
  /// placed, keeping the panel's order among themselves.
  IntColumn get sortIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, scope, targetId};
}

/// What a [CatalogOverridesTable] row applies to.
enum OverrideScope { category, channel }

@DataClassName('FavoriteRow')
class FavoritesTable extends Table {
  @override
  String get tableName => 'favorites';

  TextColumn get contentKey => text()();
  IntColumn get addedAtMillisUtc => integer()();

  /// Tombstone: a removed favourite is kept as a row with `removed = true` so
  /// the removal can propagate through sync (last-write-wins by [updatedAt]),
  /// which a bare delete could not. Hidden from My List; see FavoritesRepository
  /// (added in schema v9).
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  /// LWW key across devices — the time of the last add/remove (added in v9).
  IntColumn get updatedAtMillisUtc => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {contentKey};
}

@DataClassName('EpgRow')
class EpgCacheTable extends Table {
  @override
  String get tableName => 'epg_cache';

  TextColumn get accountId => text()();
  TextColumn get channelId => text()();
  IntColumn get startMillisUtc => integer()();
  IntColumn get stopMillisUtc => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get cachedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, channelId, startMillisUtc};
}

/// TTL bookkeeping: when each catalog slice was last refreshed from the
/// source. Distinguishes "never fetched" from "fetched and legitimately
/// empty", which row counts cannot.
@DataClassName('CatalogMetaRow')
class CatalogMetaTable extends Table {
  @override
  String get tableName => 'catalog_meta';

  TextColumn get accountId => text()();

  /// One of [CatalogKind] (stored as enum name).
  TextColumn get kind => textEnum<CatalogKind>()();
  IntColumn get refreshedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, kind};
}

/// Per-category TTL bookkeeping: when each category's *items* were last
/// fetched. [CatalogMetaTable] above tracks the slice's category *list*; this
/// tracks the contents of each category, because refreshes are per-category and
/// on demand (see `CatalogRepository`). Sweeping a whole slice is not viable on
/// a large line — 200k+ items is minutes of network that starves every read.
///
/// A separate table rather than a `categoryId` column on [CatalogMetaTable]:
/// that would change its primary key, and adding a table is a migration that
/// cannot lose the existing TTL state.
@DataClassName('CatalogCategoryMetaRow')
class CatalogCategoryMetaTable extends Table {
  @override
  String get tableName => 'catalog_category_meta';

  TextColumn get accountId => text()();

  /// One of [CatalogKind] (stored as enum name).
  TextColumn get kind => textEnum<CatalogKind>()();
  TextColumn get categoryId => text()();
  IntColumn get refreshedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, kind, categoryId};
}

/// One entry of an external ranked list (TMDB trending/popular/top-rated, or
/// the bundled award canon). Global, not account-scoped: the lists describe the
/// world, not a playlist. [DiscoveryMatchesTable] is what ties them to an
/// account's catalogue.
@DataClassName('DiscoveryTitleRow')
class DiscoveryTitlesTable extends Table {
  @override
  String get tableName => 'discovery_titles';

  TextColumn get listId => text()();

  /// Position in the source list. This IS the ranking we render — it already
  /// encodes popularity far better than any panel rating.
  IntColumn get rank => integer()();
  TextColumn get kind => textEnum<DiscoveryKind>()();
  TextColumn get title => text()();
  IntColumn get tmdbId => integer().nullable()();
  IntColumn get year => integer().nullable()();
  RealColumn get voteAverage => real().nullable()();
  IntColumn get voteCount => integer().nullable()();
  IntColumn get fetchedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {listId, rank};
}

/// A discovery entry resolved to a row in one account's catalogue. Written by a
/// single streaming pass over the catalogue (see `DiscoveryRepository`), so a
/// rail read afterwards is one indexed join rather than 150k normalisations.
@DataClassName('DiscoveryMatchRow')
class DiscoveryMatchesTable extends Table {
  @override
  String get tableName => 'discovery_matches';

  TextColumn get accountId => text()();
  TextColumn get listId => text()();
  IntColumn get rank => integer()();

  /// `movies.id` or `series.id`, per the list's kind.
  TextColumn get localId => text()();
  IntColumn get resolvedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {accountId, listId, rank};
}

/// Artwork fetched from TMDB for titles the panel supplies no image for.
///
/// Global rather than account-scoped, and keyed by the *title* rather than by a
/// local row id: the same film on two playlists is the same film, and a lookup
/// paid for once should serve both. It also survives a catalogue refresh, which
/// writing into `movies.posterUrl` would not — the panel's null would simply
/// overwrite it again on the next fetch.
///
/// [missing] records a lookup that came back empty. Without it, every title
/// TMDB does not know would be re-requested on every scroll past it forever.
@DataClassName('ArtworkRow')
class ArtworkCacheTable extends Table {
  @override
  String get tableName => 'artwork_cache';

  /// 'movie' or 'series'.
  TextColumn get kind => text()();

  /// Normalised title (+ year when known) — see `artworkKeyFor`.
  TextColumn get titleKey => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();
  IntColumn get fetchedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {kind, titleKey};
}

/// Catalog slices tracked for TTL purposes.
enum CatalogKind { live, vod, series }

/// Recent search terms (PRD §8.6). Global (not account-scoped); the query is
/// the key so re-searching a term just refreshes its timestamp.
@DataClassName('SearchHistoryRow')
class SearchHistoryTable extends Table {
  @override
  String get tableName => 'search_history';

  TextColumn get query => text()();
  IntColumn get searchedAtMillisUtc => integer()();

  @override
  Set<Column> get primaryKey => {query};
}

@DriftDatabase(tables: [
  AccountsTable,
  CategoriesTable,
  MoviesTable,
  SeriesTable,
  EpisodesTable,
  ChannelsTable,
  WatchProgressTable,
  PreferencesTable,
  FavoritesTable,
  CatalogOverridesTable,
  RemindersTable,
  EpgCacheTable,
  CatalogMetaTable,
  CatalogCategoryMetaTable,
  DiscoveryTitlesTable,
  DiscoveryMatchesTable,
  SearchHistoryTable,
  ArtworkCacheTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database in the app's documents directory.
  // Deliberately still 'aurora' after the rename to Dawn Player: this string is
  // the on-disk SQLite filename. Changing it would point the app at a fresh,
  // empty database and silently orphan every saved watch position, favourite
  // and account. A rename is not worth losing the user's history over.
  AppDatabase.open() : super(driftDatabase(name: 'aurora'));

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v2: background-playback preference.
          if (from < 2) {
            await m.addColumn(
                preferencesTable, preferencesTable.backgroundPlayback);
          }
          // v3: recent search history.
          if (from < 3) {
            await m.createTable(searchHistoryTable);
          }
          // v4: content-language filter preference.
          if (from < 4) {
            await m.addColumn(
                preferencesTable, preferencesTable.contentLanguages);
          }
          // v5: per-category TTLs, for on-demand per-category refreshes.
          if (from < 5) {
            await m.createTable(catalogCategoryMetaTable);
          }
          // v6: discovery rails (TMDB lists + the bundled award canon).
          if (from < 6) {
            await m.createTable(discoveryTitlesTable);
            await m.createTable(discoveryMatchesTable);
            await m.addColumn(preferencesTable, preferencesTable.tmdbApiKey);
            await m.addColumn(
                preferencesTable, preferencesTable.discoveryRegion);
          }
          // v7: catch-up TV — which channels the panel records, and for how
          // long. Existing rows default to "no archive" until the next live
          // refresh fills them in, so nothing has to be re-downloaded eagerly.
          if (from < 7) {
            await m.addColumn(channelsTable, channelsTable.tvArchive);
            await m.addColumn(channelsTable, channelsTable.tvArchiveDays);
          }
          // v8: artwork for titles the panel has no image for.
          if (from < 8) {
            await m.createTable(artworkCacheTable);
          }
          // v9: favourite tombstones so removals propagate. Existing rows are
          // active, stamped at their add time so a later remote edit wins.
          if (from < 9) {
            await m.addColumn(favoritesTable, favoritesTable.removed);
            await m.addColumn(favoritesTable, favoritesTable.updatedAtMillisUtc);
            await customStatement(
                'UPDATE favorites SET updated_at_millis_utc = added_at_millis_utc');
          }
          // v10: remember which series an episode belongs to, so the catalogue
          // backfill for synced episode progress can be retried instead of
          // being a one-shot that silently gave up.
          if (from < 10) {
            await m.addColumn(watchProgressTable, watchProgressTable.seriesId);
          }
          // v11: the user's hidden / renamed / reordered categories and
          // channels. Kept beside the catalogue rather than in it, because a
          // refresh replaces catalogue rows wholesale.
          if (from < 11) {
            await m.createTable(catalogOverridesTable);
          }
          // v12: theme choice and UI scale. Both nullable, so existing installs
          // keep the dark theme at its designed size without a backfill.
          if (from < 12) {
            await m.addColumn(preferencesTable, preferencesTable.themeMode);
            await m.addColumn(preferencesTable, preferencesTable.uiScale);
          }
          // v13: channel variant grouping. Backfilled here rather than left to
          // the next catalogue refresh, because the grouped query does
          // `GROUP BY variant_key` — one null key per un-backfilled row would
          // collapse the entire channel list into a single entry until that
          // refresh happened.
          if (from < 13) {
            await m.addColumn(channelsTable, channelsTable.variantKey);
            await m.addColumn(channelsTable, channelsTable.baseName);
            await m.addColumn(channelsTable, channelsTable.qualityRank);
            await m.addColumn(
                preferencesTable, preferencesTable.groupChannelVariants);
            await _backfillChannelVariants();
          }
          // v14: programme reminders. Kept locally rather than in the sync
          // payload — an alarm is scheduled against THIS device's clock, and a
          // phone's reminder firing on the television is not what anyone means
          // by "remind me".
          if (from < 14) {
            await m.createTable(remindersTable);
          }
        },
        beforeOpen: (details) async {
          // Indexes for the hot catalog queries. Without them every Home rail
          // and browse-grid page does a full table scan + sort of the whole
          // catalog, which makes a large playlist (tens of thousands of items)
          // feel very slow. Created idempotently — no schema bump needed — and
          // built once against whatever is already cached. Column/table names
          // come from drift's getters so they can't drift out of sync.
          final mv = moviesTable, sr = seriesTable, ch = channelsTable;
          Future<void> ix(String name, String table, List<String> cols) =>
              customStatement('CREATE INDEX IF NOT EXISTS $name ON $table '
                  '(${cols.join(', ')})');
          await ix('idx_mv_acct_cat', mv.actualTableName,
              [mv.accountId.name, mv.categoryId.name, mv.name.name]);
          await ix('idx_mv_acct_name', mv.actualTableName,
              [mv.accountId.name, mv.name.name]);
          await ix('idx_mv_acct_rating', mv.actualTableName,
              [mv.accountId.name, mv.rating.name]);
          await ix('idx_mv_acct_added', mv.actualTableName,
              [mv.accountId.name, mv.addedAtMillisUtc.name]);
          await ix('idx_sr_acct_cat', sr.actualTableName,
              [sr.accountId.name, sr.categoryId.name, sr.name.name]);
          await ix('idx_sr_acct_name', sr.actualTableName,
              [sr.accountId.name, sr.name.name]);
          await ix('idx_sr_acct_rating', sr.actualTableName,
              [sr.accountId.name, sr.rating.name]);
          // Channels had no index at all: a line with tens of thousands of
          // channels made every Live read a full scan plus a sort. These let a
          // paged read touch only the rows it returns.
          await ix('idx_ch_acct_sort', ch.actualTableName,
              [ch.accountId.name, ch.sortOrder.name]);
          await ix('idx_ch_acct_cat_sort', ch.actualTableName,
              [ch.accountId.name, ch.categoryId.name, ch.sortOrder.name]);
          // Variant grouping reads GROUP BY variant_key within an account.
          await ix('idx_ch_acct_variant', ch.actualTableName,
              [ch.accountId.name, ch.variantKey.name]);
        },
      );

  /// Fills in the v13 variant columns for channels cached before they existed.
  ///
  /// Paged rather than one statement: a large line holds tens of thousands of
  /// channels, and materialising all of them plus a companion each would spike
  /// memory during a migration — the one moment the app cannot recover from
  /// being killed.
  Future<void> _backfillChannelVariants() async {
    const pageSize = 2000;
    for (var offset = 0;; offset += pageSize) {
      final rows = await (select(channelsTable)..limit(pageSize, offset: offset))
          .get();
      if (rows.isEmpty) break;
      await batch((b) {
        for (final row in rows) {
          final variant = parseChannelVariant(row.name);
          b.update(
            channelsTable,
            ChannelsTableCompanion(
              variantKey: Value(variant.key),
              baseName: Value(variant.baseName),
              qualityRank: Value(variant.qualityRank),
            ),
            where: (t) =>
                t.accountId.equals(row.accountId) & t.id.equals(row.id),
          );
        }
      });
      if (rows.length < pageSize) break;
    }
  }
}
