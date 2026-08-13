library;

import 'src/catalog.dart' as base;
import 'src/cycle_companion_catalog.dart' as companion;
import 'src/models.dart';

export 'src/catalog.dart' hide healthTips;
export 'src/cycle_companion_catalog.dart' show cycleCompanionTips;
export 'src/models.dart';

final healthTips = List<HealthTip>.unmodifiable([
  ...base.healthTips,
  ...companion.cycleCompanionTips,
]);
