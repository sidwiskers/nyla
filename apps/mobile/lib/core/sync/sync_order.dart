import 'package:sync_core/sync_core.dart';

import '../../data/database/app_database.dart';

/// Returns local operations in causal order before they are handed to the
/// relay. Database insertion timestamps are intentionally not used for ties:
/// several field mutations from one transaction can share the same millisecond.
List<LocalMutationEntry> orderPendingMutations(Iterable<LocalMutationEntry> source) {
  final ordered = source.toList(growable: false)..sort((left, right) {
      final byClock = HybridLogicalClock.parse(left.hlc).compareTo(HybridLogicalClock.parse(right.hlc));
      if (byClock != 0) return byClock;
      return left.opId.compareTo(right.opId);
    });
  return ordered;
}
