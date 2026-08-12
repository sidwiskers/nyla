import 'package:sync_core/sync_core.dart';
import 'package:test/test.dart';

void main() {
  test('round trips and orders deterministically', () {
    final value = HybridLogicalClock.parse('1000:2:device_a');
    expect(value.toString(), '1000:2:device_a');
    expect(value.compareTo(HybridLogicalClock.parse('1000:3:device_a')), lessThan(0));
    expect(value.compareTo(HybridLogicalClock.parse('1000:2:device_b')), lessThan(0));
  });

  test('same millisecond increments logical counter', () {
    final first = nextLocalHlc(nodeId: 'a', nowMillis: 1000);
    final second = nextLocalHlc(nodeId: 'a', nowMillis: 1000, previous: first);
    expect(second.toString(), '1000:1:a');
  });

  test('clock moving backwards never moves HLC backwards', () {
    const previous = HybridLogicalClock(physicalMillis: 2000, logical: 4, nodeId: 'a');
    final next = nextLocalHlc(nodeId: 'a', nowMillis: 1500, previous: previous);
    expect(next.toString(), '2000:5:a');
  });

  test('observing remote timestamp advances local causality', () {
    const local = HybridLogicalClock(physicalMillis: 2000, logical: 2, nodeId: 'a');
    const remote = HybridLogicalClock(physicalMillis: 3000, logical: 7, nodeId: 'b');
    final next = observeRemoteHlc(nodeId: 'a', nowMillis: 2500, previous: local, remote: remote);
    expect(next.toString(), '3000:8:a');
  });

  test('rejects malformed timestamps', () {
    for (final invalid in ['', '1', '1:2', '-1:0:a', '1:-2:a', '1:2:a:b']) {
      expect(() => HybridLogicalClock.parse(invalid), throwsFormatException);
    }
  });
}
