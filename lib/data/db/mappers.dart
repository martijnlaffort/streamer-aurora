import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import 'app_database.dart';

/// Row ↔ domain-model mapping. The UTC discipline lives here: every
/// `*MillisUtc` integer becomes a `DateTime` with `isUtc: true`, and every
/// stored `DateTime` is normalized through [utcMillis] first.

int utcMillis(DateTime dt) => dt.toUtc().millisecondsSinceEpoch;

int? utcMillisOrNull(DateTime? dt) => dt == null ? null : utcMillis(dt);

DateTime fromUtcMillis(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

DateTime? fromUtcMillisOrNull(int? millis) =>
    millis == null ? null : fromUtcMillis(millis);

// --- Accounts ----------------------------------------------------------------

extension AccountRowMapper on AccountRow {
  /// [password] comes from secure storage — never from the database.
  Account toModel({required String password}) => Account(
        id: id,
        type: type,
        name: name,
        serverUrl: serverUrl,
        username: username,
        password: password,
        createdAt: fromUtcMillis(createdAtMillisUtc),
        epgUrl: epgUrl,
      );
}

extension AccountMapper on Account {
  AccountsTableCompanion toCompanion() => AccountsTableCompanion.insert(
        id: id,
        type: type,
        name: name,
        serverUrl: serverUrl,
        username: username,
        epgUrl: Value(epgUrl),
        createdAtMillisUtc: utcMillis(createdAt),
      );
}

// --- Catalog -----------------------------------------------------------------

extension CategoryRowMapper on CategoryRow {
  Category toModel() => Category(
      id: id, accountId: accountId, type: type, name: name, sortOrder: sortOrder);
}

extension CategoryMapper on Category {
  CategoriesTableCompanion toCompanion() => CategoriesTableCompanion.insert(
      id: id, accountId: accountId, type: type, name: name, sortOrder: sortOrder);
}

extension MovieRowMapper on MovieRow {
  Movie toModel() => Movie(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        rating: rating,
        year: year,
        plot: plot,
        genre: genre,
        cast: cast,
        durationSeconds: durationSeconds,
        containerExt: containerExt,
        addedAt: fromUtcMillisOrNull(addedAtMillisUtc),
        cachedAt: fromUtcMillis(cachedAtMillisUtc),
      );
}

extension MovieMapper on Movie {
  MoviesTableCompanion toCompanion() => MoviesTableCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        posterUrl: Value(posterUrl),
        backdropUrl: Value(backdropUrl),
        rating: Value(rating),
        year: Value(year),
        plot: Value(plot),
        genre: Value(genre),
        cast: Value(cast),
        durationSeconds: Value(durationSeconds),
        containerExt: Value(containerExt),
        addedAtMillisUtc: Value(utcMillisOrNull(addedAt)),
        cachedAtMillisUtc: utcMillis(cachedAt),
      );
}

extension SeriesRowMapper on SeriesRow {
  Series toModel() => Series(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        posterUrl: posterUrl,
        backdropUrl: backdropUrl,
        rating: rating,
        year: year,
        plot: plot,
        genre: genre,
        cast: cast,
        cachedAt: fromUtcMillis(cachedAtMillisUtc),
      );
}

extension SeriesMapper on Series {
  SeriesTableCompanion toCompanion() => SeriesTableCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        posterUrl: Value(posterUrl),
        backdropUrl: Value(backdropUrl),
        rating: Value(rating),
        year: Value(year),
        plot: Value(plot),
        genre: Value(genre),
        cast: Value(cast),
        cachedAtMillisUtc: utcMillis(cachedAt),
      );
}

extension EpisodeRowMapper on EpisodeRow {
  Episode toModel() => Episode(
        id: id,
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        title: title,
        plot: plot,
        durationSeconds: durationSeconds,
        stillUrl: stillUrl,
        containerExt: containerExt,
        airDate: fromUtcMillisOrNull(airDateMillisUtc),
        cachedAt: fromUtcMillis(cachedAtMillisUtc),
      );
}

extension EpisodeMapper on Episode {
  EpisodesTableCompanion toCompanion({required String accountId}) =>
      EpisodesTableCompanion.insert(
        id: id,
        accountId: accountId,
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        title: title,
        plot: Value(plot),
        durationSeconds: Value(durationSeconds),
        stillUrl: Value(stillUrl),
        containerExt: Value(containerExt),
        airDateMillisUtc: Value(utcMillisOrNull(airDate)),
        cachedAtMillisUtc: utcMillis(cachedAt),
      );
}

extension ChannelRowMapper on ChannelRow {
  Channel toModel() => Channel(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        logoUrl: logoUrl,
        epgChannelId: epgChannelId,
        sortOrder: sortOrder,
        cachedAt: fromUtcMillis(cachedAtMillisUtc),
      );
}

extension ChannelMapper on Channel {
  ChannelsTableCompanion toCompanion() => ChannelsTableCompanion.insert(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        name: name,
        logoUrl: Value(logoUrl),
        epgChannelId: Value(epgChannelId),
        sortOrder: Value(sortOrder),
        cachedAtMillisUtc: utcMillis(cachedAt),
      );
}

// --- Progress / preferences / favorites / EPG --------------------------------

extension WatchProgressRowMapper on WatchProgressRow {
  WatchProgress toModel() => WatchProgress(
        contentKey: contentKey,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        updatedAt: fromUtcMillis(updatedAtMillisUtc),
        syncedAt: fromUtcMillisOrNull(syncedAtMillisUtc),
        completed: completed,
      );
}

extension WatchProgressMapper on WatchProgress {
  WatchProgressTableCompanion toCompanion() =>
      WatchProgressTableCompanion.insert(
        contentKey: contentKey,
        positionSeconds: positionSeconds,
        durationSeconds: durationSeconds,
        updatedAtMillisUtc: utcMillis(updatedAt),
        syncedAtMillisUtc: Value(utcMillisOrNull(syncedAt)),
        completed: Value(completed),
      );
}

extension PreferencesRowMapper on PreferencesRow {
  Preferences toModel() => Preferences(
        preferredAudioLang: preferredAudioLang,
        preferredSubtitleLang: preferredSubtitleLang,
        autoplayNext: autoplayNext,
      );
}

extension EpgRowMapper on EpgRow {
  EpgEntry toModel() => EpgEntry(
        channelId: channelId,
        start: fromUtcMillis(startMillisUtc),
        stop: fromUtcMillis(stopMillisUtc),
        title: title,
        description: description,
      );
}
