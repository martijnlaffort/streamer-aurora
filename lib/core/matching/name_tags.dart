/// The bracketing panels put in front of every name, and how to take it off.
///
/// Shared by `prettyTitle` (films and series) and `prettyCategoryName` so the
/// two cannot drift apart — they already had, with categories recognising three
/// separator characters and titles nine, which meant a provider using an
/// unusual bar cleaned one and not the other.
library;

/// Vertical-bar characters seen in the wild, including the look-alikes.
///
/// Panels are authored in every script, and several use a character that merely
/// LOOKS like `|`: the Cyrillic palochka and Greek capital iota are visually
/// identical in most fonts, and the box-drawing and "light vertical bar" forms
/// are common in generated names.
const _barChars = '|¦｜∣│┃‖ǀǁ❘❙❚⏐⎮⎪┆┇┊┋╎╏║ӀӏΙІӀ';

/// Everything treated as a name separator: bars plus the bullet forms.
final kNameSeparators = RegExp('[$_barChars•·]+');

/// Removes a leading `<X>tag<X>` bracket, whatever `X` happens to be.
///
/// The character set above can only ever be a list of the bars we have already
/// met. This is the structural fallback for the ones we have not: if a name
/// STARTS with a non-alphanumeric character, that same character occurs again,
/// and everything between the two is language/packaging noise, then it is a
/// bracketed tag no matter which glyph the provider chose.
///
/// Deliberately narrow, because the alternative — treating any punctuation run
/// as a separator — would file `Mission: Impossible` under `Impossible`:
///
///  * the name has to BEGIN with the character, so `Mission: Impossible` and
///    `Marvel's Agents of S.H.I.E.L.D.` are never touched;
///  * the character has to appear a SECOND time, so `(500) Days of Summer` and
///    `#1 Cheerleader Camp` are never touched;
///  * the enclosed text has to be entirely noise, so `"Crocodile" Dundee` keeps
///    its quotes and its name.
///
/// [isNoise] decides what counts as a tag — the two callers disagree slightly
/// about that, which is why it is a parameter.
String stripLeadingTag(String raw, bool Function(String) isNoise) {
  var text = raw.trim();
  // Up to three, because panels stack them: `| MULTI || NL | Name`.
  for (var pass = 0; pass < 3; pass++) {
    if (text.length < 2) break;
    final opener = text[0];
    // A letter, digit or space opens a name, not a tag.
    if (RegExp(r'[\p{L}\p{N}\s]', unicode: true).hasMatch(opener)) break;
    final close = text.indexOf(opener, 1);
    if (close < 1) break;
    final inner = text.substring(1, close).trim();
    if (inner.isEmpty || !isNoise(inner)) break;
    text = text.substring(close + 1).trim();
  }
  return text;
}
