import 'package:equatable/equatable.dart';

import 'enums.dart';

/// A catalog category/group (PRD §7 `categories`) — an Xtream category or an
/// M3U `group-title`.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.accountId,
    required this.type,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String accountId;
  final CategoryType type;
  final String name;
  final int sortOrder;

  @override
  List<Object?> get props => [id, accountId, type, name, sortOrder];

  @override
  bool get stringify => true;
}
