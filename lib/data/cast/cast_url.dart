import '../../domain/models/models.dart';

/// What a Chromecast can be asked to play, and what it cannot.
///
/// Casting is not mirroring: the Chromecast fetches the URL and decodes it with
/// its own player, and the stock receiver handles MP4, HLS and DASH — not raw
/// MPEG-TS and not MKV. That single fact decides this whole feature, so the
/// decision lives here rather than being spread over the UI.
///
/// The useful consequence is for LIVE channels. Their default URL ends `.ts`,
/// which a Chromecast cannot touch — but most Xtream panels serve the same
/// channel as HLS if you ask for `.m3u8` instead, and HLS it can play. So live
/// TV is cast by swapping the extension rather than being refused outright.
/// Panels that do not offer HLS will fail at the receiver; that surfaces as a
/// normal cast error rather than something we can detect in advance.
class CastTarget {
  /// Ready to hand to the receiver.
  const CastTarget.playable({
    required this.url,
    required this.contentType,
    required this.isLive,
  }) : refusal = null;

  /// Not castable, with a sentence worth showing the user.
  const CastTarget.refused(this.refusal)
      : url = null,
        contentType = null,
        isLive = false;

  final String? url;
  final String? contentType;
  final bool isLive;

  /// Why this stream cannot be cast, or null when it can.
  final String? refusal;

  bool get canCast => url != null;
}

/// Containers the stock receiver plays.
const _castableVod = {'mp4', 'm4v', 'mov', 'webm'};

/// Containers it does not, listed so the message can name the reason.
const _knownUncastable = {'mkv', 'avi', 'ts', 'flv', 'wmv', 'mpg', 'mpeg', 'm2ts'};

/// Decides how (or whether) [ref] can be cast, given the URL the source built.
///
/// [streamUrl] is the normal playback URL — the same one libmpv would open — so
/// this stays a pure function of what the panel already told us.
CastTarget castTargetFor(StreamRef ref, String streamUrl) {
  if (ref.isCatchup) {
    // Timeshift is served as a TS slice with no HLS equivalent.
    return const CastTarget.refused(
        'Catch-up recordings can’t be cast — a Chromecast can’t play this '
        'format. Play it on this device instead.');
  }

  if (ref.type == StreamType.live) {
    // Ask the panel for HLS instead of the raw transport stream.
    final hls = _withExtension(streamUrl, 'm3u8');
    return CastTarget.playable(
      url: hls,
      contentType: 'application/x-mpegURL',
      isLive: true,
    );
  }

  final ext = (ref.containerExt ?? 'mp4').toLowerCase();
  if (_castableVod.contains(ext)) {
    return CastTarget.playable(
      url: streamUrl,
      contentType: ext == 'webm' ? 'video/webm' : 'video/mp4',
      isLive: false,
    );
  }
  if (_knownUncastable.contains(ext)) {
    return CastTarget.refused(
        'A Chromecast can’t play .$ext files. Play it on this device instead.');
  }
  // Unknown container: try it as MP4 rather than refusing something that might
  // work. A receiver that cannot decode it reports an error of its own.
  return CastTarget.playable(
    url: streamUrl,
    contentType: 'video/mp4',
    isLive: false,
  );
}

/// Replaces the URL's final extension, leaving any query string alone.
String _withExtension(String url, String extension) {
  final queryAt = url.indexOf('?');
  final path = queryAt == -1 ? url : url.substring(0, queryAt);
  final query = queryAt == -1 ? '' : url.substring(queryAt);
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  if (dot <= slash) return '$path.$extension$query'; // no extension to replace
  return '${path.substring(0, dot)}.$extension$query';
}
