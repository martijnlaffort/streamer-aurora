import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  IntColumn get cachedAtMillisUtc => integer()();

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

  /// App state, not a user preference — which account the UI is showing.
  TextColumn get activeAccountId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FavoriteRow')
class FavoritesTable extends Table {
  @override
  String get tableName => 'favorites';

  TextColumn get contentKey => text()();
  IntColumn get addedAtMillisUtc => integer()();

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
  EpgCacheTable,
  CatalogMetaTable,
  CatalogCategoryMetaTable,
  DiscoveryTitlesTable,
  DiscoveryMatchesTable,
  SearchHistoryTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database in the app's documents directory.
  AppDatabase.open() : super(driftDatabase(name: 'aurora'));

  @override
  int get schemaVersion => 6;

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
        },
      );
}
