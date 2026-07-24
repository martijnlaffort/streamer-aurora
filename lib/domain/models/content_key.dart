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
