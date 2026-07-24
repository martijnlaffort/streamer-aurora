import 'enums.dart';

/// Stable identity for one piece of content across repositories
/// (PRD §7: `account:type:id`). Used by watch progress and favorites.
String contentKeyFor({
  required String accountId,
  required StreamType type,
  required String id,
}) =>
    '$accountId:${type.name}:$id';

/// The `accountId` component of a content key (for account-scoped cleanup).
String accountIdOfContentKey(String contentKey) =>
    contentKey.split(':').first;

/// Splits `account:type:id` back into its parts; null if malformed.
({String accountId, String type, String id})? parseContentKey(
    String contentKey) {
  final parts = contentKey.split(':');
  if (parts.length < 3) return null;
  return (
    accountId: parts[0],
    type: parts[1],
    // Ids never contain ':' today, but don't truncate if that changes.
    id: parts.sublist(2).join(':'),
  );
}
