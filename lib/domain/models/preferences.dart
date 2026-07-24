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
  });

  const Preferences.defaults() : this();

  /// Explicit "subtitles off" marker for [preferredSubtitleLang].
  static const String subsOff = 'off';

  final String? preferredAudioLang;
  final String? preferredSubtitleLang;
  final bool autoplayNext;

  Preferences copyWith({
    String? preferredAudioLang,
    String? preferredSubtitleLang,
    bool? autoplayNext,
  }) {
    return Preferences(
      preferredAudioLang: preferredAudioLang ?? this.preferredAudioLang,
      preferredSubtitleLang:
          preferredSubtitleLang ?? this.preferredSubtitleLang,
      autoplayNext: autoplayNext ?? this.autoplayNext,
    );
  }

  @override
  List<Object?> get props =>
      [preferredAudioLang, preferredSubtitleLang, autoplayNext];

  @override
  bool get stringify => true;
}
