import 'package:equatable/equatable.dart';

/// Which palette the app uses. `system` follows the device setting.
enum AppThemeMode { system, light, dark }

/// The sizing choices offered in Settings, and what they multiply by.
///
/// A small named set rather than a free slider: the useful range is narrow, and
/// three labelled steps are far easier to operate with a remote than a slider.
enum UiSize {
  compact(0.9, 'Compact'),
  standard(1.0, 'Standard'),
  large(1.15, 'Large'),
  extraLarge(1.3, 'Extra large');

  const UiSize(this.scale, this.label);

  final double scale;
  final String label;

  /// Nearest step to a stored multiplier, so a value written by another build
  /// still lands on something selectable.
  static UiSize nearest(double scale) => UiSize.values.reduce((a, b) =>
      (a.scale - scale).abs() <= (b.scale - scale).abs() ? a : b);
}

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
    this.themeMode = AppThemeMode.dark,
    this.uiScale = 1.0,
    this.groupChannelVariants = true,
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

  /// Which palette to use. Dark is the default and the design of record.
  final AppThemeMode themeMode;

  /// Multiplier for text and poster sizes, 1.0 being the designed size.
  ///
  /// Device-local, like the TMDB key and the language filter: it is not part of
  /// the sync payload, so a phone set to Compact does not shrink the TV.
  final double uiScale;

  /// Collapse the rows a line ships for one channel (`NPO 1`, `NPO 1 HD`,
  /// `NPO 1 FHD`) into a single entry that plays the best of them.
  ///
  /// On by default: a real line lists most channels three or four times, and
  /// the uncollapsed list is the thing that makes 25k channels unbrowsable.
  ///
  /// Device-local, like [uiScale]: the sync payload does not carry it, so a
  /// pull must not be allowed to reset it (see `_reconcilePreferences`).
  final bool groupChannelVariants;

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
    AppThemeMode? themeMode,
    double? uiScale,
    bool? groupChannelVariants,
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
      themeMode: themeMode ?? this.themeMode,
      uiScale: uiScale ?? this.uiScale,
      groupChannelVariants:
          groupChannelVariants ?? this.groupChannelVariants,
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
        themeMode,
        uiScale,
        groupChannelVariants,
      ];

  @override
  bool get stringify => true;
}
