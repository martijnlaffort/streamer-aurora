/// Where an account's catalog comes from (PRD §6).
enum AccountType { xtream, m3u }

/// Which catalog a category belongs to (PRD §7).
enum CategoryType { live, vod, series }

/// What kind of stream a [StreamRef] points at — determines the URL shape
/// (PRD §6.1).
enum StreamType { live, movie, episode }
