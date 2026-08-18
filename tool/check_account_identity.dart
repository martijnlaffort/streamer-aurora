// Checks stableAccountId: the same playlist must always produce the same id
// (that is the entire point — it is what lets two devices share a namespace and
// what makes re-adding a playlist keep its history), while genuinely different
// playlists must not collide.
//
//   dart run tool/check_account_identity.dart
//
// ignore_for_file: avoid_print — command-line tool; stdout IS its UI.
import 'package:dawnplayer/domain/models/account_identity.dart';
import 'package:dawnplayer/domain/models/enums.dart';

String id(String server, String user, [AccountType type = AccountType.xtream]) =>
    stableAccountId(type: type, serverUrl: server, username: user);

void main() {
  var failures = 0;

  void expect(String label, bool condition) {
    if (!condition) failures++;
    print('  [${condition ? 'ok ' : 'FAIL'}] $label');
  }

  const server = 'http://panel.example.com:8080';
  final base = id(server, 'martijn');

  print('same playlist, written differently — must all agree:');
  for (final variant in [
    'http://panel.example.com:8080/',
    'http://panel.example.com:8080///',
    'HTTP://Panel.Example.COM:8080',
    '  http://panel.example.com:8080  ',
  ]) {
    expect('"$variant"', id(variant, 'martijn') == base);
  }
  expect('default port :80 == omitted port',
      id('http://a.example.com:80', 'u') == id('http://a.example.com', 'u'));
  expect('https default port :443 == omitted',
      id('https://a.example.com:443', 'u') == id('https://a.example.com', 'u'));
  expect('username whitespace is trimmed',
      id(server, '  martijn  ') == base);
  expect('stable across calls', id(server, 'martijn') == base);

  print('genuinely different playlists — must NOT collide:');
  expect('different username', id(server, 'someone') != base);
  expect('different host', id('http://other.example.com:8080', 'martijn') != base);
  expect('different port', id('http://panel.example.com:9090', 'martijn') != base);
  expect('different scheme',
      id('https://panel.example.com:8080', 'martijn') != base);
  expect('subdirectory panels stay distinct',
      id('$server/panel', 'martijn') != base);
  expect('different account type',
      id(server, 'martijn', AccountType.m3u) != base);
  // Case-sensitive on purpose: merging two real logins is worse than failing to
  // merge one that was retyped.
  expect('username case is significant', id(server, 'Martijn') != base);

  print('shape:');
  expect('prefixed and fixed length', base.startsWith('acc_') && base.length == 28);

  print(failures == 0 ? '\nPASS' : '\n$failures FAILED');
}
