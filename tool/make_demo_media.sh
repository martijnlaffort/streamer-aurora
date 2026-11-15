#!/usr/bin/env bash
# Builds the App Review demo media from the Blender Foundation's open movies,
# so every item in demo/demo.m3u is CC BY licensed and hosted on dawnplayer.com.
#
#   Big Buck Bunny -> HLS, two renditions (720p, 360p), 6 s MPEG-TS segments.
#   Sintel         -> one MKV with the film's subtitle languages as separate
#                     tracks: what the review uses to show language memory.
#   Both           -> a poster frame (.jpg) for the playlist.
#
# Usage:
#   tool/make_demo_media.sh <big_buck_bunny video> <sintel video> <subtitle dir> [out dir]
#
#   <subtitle dir> holds Sintel's subtitle files named sintel_<code>.srt, e.g.
#   sintel_fr.srt, sintel_nl.srt, sintel_jp.srt, as published at
#   https://download.blender.org/durian/subs/ (there is no English file; the
#   film is in English). They are published
#   with the film by the Blender Foundation under the same CC BY licence.
#   [out dir] defaults to build/demo. Upload its contents to
#   https://dawnplayer.com/demo/ as they are.
#
# Needs ffmpeg with libx264. Every output file stays under 100 MB, which is
# GitHub Pages' per-file limit.
set -euo pipefail

if [ $# -lt 3 ]; then
  sed -n '2,22p' "$0"
  exit 1
fi

BBB="$1"
SINTEL="$2"
SUBS="$3"
OUT="${4:-build/demo}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$OUT/big_buck_bunny/720p" "$OUT/big_buck_bunny/360p"

echo "==> Big Buck Bunny -> HLS"
# Keyframes forced every 6 s so every segment starts on one and both
# renditions cut at the same points (clean switching between them).
ffmpeg -hide_banner -loglevel warning -stats -y -i "$BBB" \
  -filter_complex "[0:v]split=2[a][b];[a]scale=-2:720[v720];[b]scale=-2:360[v360]" \
  -map "[v720]" -map "[v360]" -map 0:a:0 -map 0:a:0 \
  -c:v libx264 -preset slow -profile:v main -pix_fmt yuv420p \
  -force_key_frames "expr:gte(t,n_forced*6)" \
  -crf:v:0 23 -maxrate:v:0 2500k -bufsize:v:0 5000k \
  -crf:v:1 26 -maxrate:v:1 700k -bufsize:v:1 1400k \
  -c:a aac -b:a 128k -ac 2 \
  -f hls -hls_time 6 -hls_playlist_type vod -hls_segment_type mpegts \
  -hls_segment_filename "$OUT/big_buck_bunny/%v/seg_%03d.ts" \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0,name:720p v:1,a:1,name:360p" \
  "$OUT/big_buck_bunny/%v/index.m3u8"

echo "==> Sintel -> MKV with subtitle tracks"
# ISO 639-2 codes, which is what Matroska stores and mpv reports, plus each
# language's own name as the track title (what the subtitle menu shows).
# The codes are the ones Blender's subs folder actually uses, several of which
# are not ISO codes (jp, gr, cz, swe). An unknown code is skipped, not guessed.
lang3() {
  case "$1" in
    fr) echo "fre Français" ;;     nl) echo "dut Nederlands" ;;
    pl) echo "pol Polski" ;;       ru) echo "rus Русский" ;;
    jp) echo "jpn 日本語" ;;        gr) echo "gre Ελληνικά" ;;
    cz) echo "cze Čeština" ;;      swe) echo "swe Svenska" ;;
    da) echo "dan Dansk" ;;        hu) echo "hun Magyar" ;;
    tr) echo "tur Türkçe" ;;       ko) echo "kor 한국어" ;;
    ro) echo "rum Română" ;;       sk) echo "slo Slovenčina" ;;
    *) return 1 ;;
  esac
}

inputs=()
maps=()
meta=()
n=0
shopt -s nullglob
for srt in "$SUBS"/sintel_*.srt; do
  code="$(basename "$srt" .srt)"
  code="${code#sintel_}"
  if ! pair="$(lang3 "$code")"; then
    echo "    skipping $srt: no mapping for '$code'"
    continue
  fi
  read -r iso title <<<"$pair"
  # Files from 2011 are not all UTF-8. Pass ffmpeg the real encoding when
  # `file` can name it; skip one it cannot, rather than burn in mojibake.
  charset="$(file -b --mime-encoding "$srt" 2>/dev/null || echo unknown)"
  case "$charset" in
    utf-8 | us-ascii) charset=UTF-8 ;;
    iso-8859-* | windows-*) ;;
    *)
      echo "    skipping $srt: unrecognised encoding '$charset'"
      continue
      ;;
  esac
  inputs+=(-sub_charenc "$charset" -i "$srt")
  maps+=(-map "$((n + 1)):0")
  meta+=(-metadata:s:s:$n "language=$iso" -metadata:s:s:$n "title=$title")
  n=$((n + 1))
done
if [ "$n" -eq 0 ]; then
  echo "!! no sintel_<code>.srt files in $SUBS" >&2
  exit 1
fi
echo "    $n subtitle languages"

# 480p at a capped rate: the 14:48 film lands around 75 MB.
ffmpeg -hide_banner -loglevel warning -stats -y -i "$SINTEL" "${inputs[@]}" \
  -map 0:v:0 -map 0:a:0 "${maps[@]}" \
  -c:v libx264 -preset slow -pix_fmt yuv420p -vf scale=-2:480 \
  -crf 24 -maxrate 600k -bufsize 1200k \
  -c:a aac -b:a 96k -ac 2 -metadata:s:a:0 language=eng \
  -c:s srt "${meta[@]}" \
  -disposition:s 0 \
  "$OUT/sintel.mkv"

echo "==> Posters"
ffmpeg -hide_banner -loglevel error -y -ss 60 -i "$BBB" -frames:v 1 \
  -vf scale=600:-2 -q:v 3 "$OUT/big_buck_bunny.jpg"
ffmpeg -hide_banner -loglevel error -y -ss 120 -i "$SINTEL" -frames:v 1 \
  -vf scale=600:-2 -q:v 3 "$OUT/sintel.jpg"

cp "$ROOT/demo/demo.m3u" "$OUT/demo.m3u"

echo "==> Done: $OUT"
find "$OUT" -type f -size +95M -exec echo "!! over GitHub Pages' limit: {}" \;
du -sh "$OUT"
