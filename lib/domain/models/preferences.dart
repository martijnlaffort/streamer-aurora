import 'package:equatable/equatable.dart';

/// Global playback preferences (PRD §7 `preferences`, language logic in §8.10).
///
/// Language values are ISO 639 tags as they appear on stream tracks ("eng",
/// "nl"). `null` means "no preference yet"; subtitles additionally use [subsOff]
/// as an explicit "Off" choice, distinct from unset.
class Preferences extends Equatable {
  const Preferences({
    this.preferredAudioLang,
    this.preferredSubtitleLang,
    this.autoplayNext = true,
    this.backgroundPlayback = false,
    this.contentLanguages,
    this.tmdbApiKey,
    this.discoveryRegion,
  });

  const Preferences.defaults() : this();

  /// Explicit "subtitles off" marker for [preferredSubtitleLang].
  static const String subsOff = 'off';

  final String? preferredAudioLang;
  final String? preferredSubtitleLang;
  final bool autoplayNext;

  /// Keep audio playing when the app is backgrounded (PRD §8.8, Task 2.3).
  final bool backgroundPlayback;

  /// Content-language filter (PRD §8.3): the ContentLanguage codes to *show*
  /// in the catalog. `null` means "not configured" → show every language.
  final List<String>? contentLanguages;

  /// TMDB v3 API key powering the discovery rails; `null` → those rails are
  /// hidden and only the bundled award rails show.
  final String? tmdbApiKey;

  /// ISO 3166-1 country for region-aware discovery; `null` → device locale.
  final String? discoveryRegion;

  /// Prefer this over constructing a whole [Preferences] when saving one
  /// setting: a full construction silently drops any field the caller forgot,
  /// which is how a language change would wipe the TMDB key.
  ///
  /// `copyWith` cannot express "set this back to null", so the fields that need
  /// clearing get an explicit flag.
  Preferences copyWith({
    String? preferredAudioLang,
    String? preferredSubtitleLang,
    bool? autoplayNext,
    bool? backgroundPlayback,
    List<String>? contentLanguages,
    String? tmdbApiKey,
    String? discoveryRegion,
    bool clearTmdbApiKey = false,
    bool clearContentLanguages = false,
  }) {
    return Preferences(
      preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
      preferredSubtitleLang:
          preferredSubtitleLang ?? this.preferredSubtitleLang,
      autoplayNext: autoplayNext ?? this.autoplayNext,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      contentLanguages: clearContentLanguages
          ? null
          : (contentLanguages ?? this.contentLanguages),
      tmdbApiKey: clearTmdbApiKey ? null : (tmdbApiKey ?? this.tmdbApiKey),
      discoveryRegion: discoveryRegion ?? this.discoveryRegion,
    );
  }

  @override
  List<Object?> get props => [
        preferredAudioLang,
        preferredSubtitleLang,
        autoplayNext,
        backgroundPlayback,
        contentLanguages,
        tmdbApiKey,
        discoveryRegion,
      ];

  @override
  bool get stringify => true;
}
