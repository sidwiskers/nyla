/// A Hybrid Logical Clock timestamp.
///
/// Ordering is physical milliseconds, then logical counter, then node ID. The
/// node tie-breaker gives every device the same deterministic total order.
final class HybridLogicalClock implements Comparable<HybridLogicalClock> {
  const HybridLogicalClock({
    required this.physicalMillis,
    required this.logical,
    required this.nodeId,
  })  : assert(physicalMillis >= 0),
        assert(logical >= 0),
        assert(nodeId != '');

  final int physicalMillis;
  final int logical;
  final String nodeId;

  factory HybridLogicalClock.parse(String value) {
    final first = value.indexOf(':');
    final second = first < 0 ? -1 : value.indexOf(':', first + 1);
    if (first <= 0 || second <= first + 1 || second == value.length - 1) {
      throw FormatException('Invalid HLC', value);
    }
    final physical = int.tryParse(value.substring(0, first));
    final logical = int.tryParse(value.substring(first + 1, second));
    final node = value.substring(second + 1);
    if (physical == null || physical < 0 || logical == null || logical < 0 || node.contains(':')) {
      throw FormatException('Invalid HLC', value);
    }
    return HybridLogicalClock(physicalMillis: physical, logical: logical, nodeId: node);
  }

  @override
  int compareTo(HybridLogicalClock other) {
    final physicalOrder = physicalMillis.compareTo(other.physicalMillis);
    if (physicalOrder != 0) return physicalOrder;
    final logicalOrder = logical.compareTo(other.logical);
    if (logicalOrder != 0) return logicalOrder;
    return nodeId.compareTo(other.nodeId);
  }

  bool isAfter(HybridLogicalClock other) => compareTo(other) > 0;

  @override
  String toString() => '$physicalMillis:$logical:$nodeId';

  @override
  bool operator ==(Object other) =>
      other is HybridLogicalClock &&
      other.physicalMillis == physicalMillis &&
      other.logical == logical &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(physicalMillis, logical, nodeId);
}

HybridLogicalClock nextLocalHlc({
  required String nodeId,
  required int nowMillis,
  HybridLogicalClock? previous,
}) {
  _validateNode(nodeId);
  if (nowMillis < 0) throw ArgumentError.value(nowMillis, 'nowMillis', 'Must be non-negative');

  if (previous == null || nowMillis > previous.physicalMillis) {
    return HybridLogicalClock(physicalMillis: nowMillis, logical: 0, nodeId: nodeId);
  }
  return HybridLogicalClock(
    physicalMillis: previous.physicalMillis,
    logical: previous.logical + 1,
    nodeId: nodeId,
  );
}

HybridLogicalClock observeRemoteHlc({
  required String nodeId,
  required int nowMillis,
  HybridLogicalClock? previous,
  required HybridLogicalClock remote,
}) {
  _validateNode(nodeId);
  if (nowMillis < 0) throw ArgumentError.value(nowMillis, 'nowMillis', 'Must be non-negative');
  final localPhysical = previous?.physicalMillis ?? 0;
  final maximumPhysical = _max3(nowMillis, localPhysical, remote.physicalMillis);

  int logical;
  if (maximumPhysical == localPhysical && maximumPhysical == remote.physicalMillis) {
    final localLogical = previous?.logical ?? 0;
    logical = (localLogical > remote.logical ? localLogical : remote.logical) + 1;
  } else if (maximumPhysical == localPhysical) {
    logical = (previous?.logical ?? 0) + 1;
  } else if (maximumPhysical == remote.physicalMillis) {
    logical = remote.logical + 1;
  } else {
    logical = 0;
  }

  return HybridLogicalClock(
    physicalMillis: maximumPhysical,
    logical: logical,
    nodeId: nodeId,
  );
}

void _validateNode(String nodeId) {
  if (nodeId.isEmpty || nodeId.contains(':')) {
    throw ArgumentError.value(nodeId, 'nodeId', 'Must be non-empty and cannot contain a colon');
  }
}

int _max3(int a, int b, int c) {
  var result = a > b ? a : b;
  if (c > result) result = c;
  return result;
}
