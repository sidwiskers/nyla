import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/notifications/notification_config.dart';
import '../../core/security/app_lock_service.dart';
import '../../core/theme/nyla_appearance.dart';
import '../../core/theme/nyla_theme.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(notificationConfigProvider);
    final config = configAsync.value ?? const NotificationConfig();
    final appearance = ref.watch(effectiveAppearanceProvider);
    final palette = context.nyla;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.pageTop, palette.canvas, palette.pageBottom],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth > 796
                  ? (constraints.maxWidth - 760) / 2
                  : 18.0;
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  side,
                  MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  side,
                  42,
                ),
                children: [
                  _PrivacyPanel(
                    privacy: config.privacy,
                    onPrivacyChanged: (value) async {
                      await NylaHaptics.select();
                      await _save(ref, config.copyWith(privacy: value));
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    eyebrow: 'APPEARANCE',
                    title: 'Appearance',
                    subtitle: 'Follow your phone or choose a look.',
                  ),
                  const SizedBox(height: 12),
                  _AppearancePanel(
                    value: appearance,
                    onChanged: (value) async {
                      if (value == appearance) return;
                      await NylaHaptics.select();
                      await ref
                          .read(preferencesRepositoryProvider)
                          .setAppearance(value);
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    eyebrow: 'REMINDERS',
                    title: 'Reminders',
                    subtitle: 'Period and check-in alerts.',
                  ),
                  const SizedBox(height: 12),
                  _ReminderPanel(
                    config: config,
                    onPeriodApproaching: (enabled) => _toggleWithPermission(
                      context,
                      ref,
                      enabled,
                      config.copyWith(periodApproaching: enabled),
                    ),
                    onExpectedWindow: (enabled) => _toggleWithPermission(
                      context,
                      ref,
                      enabled,
                      config.copyWith(expectedWindowStarts: enabled),
                    ),
                    onDailyLog: (enabled) => _toggleWithPermission(
                      context,
                      ref,
                      enabled,
                      config.copyWith(dailyLogReminder: enabled),
                    ),
                    onLeadTime: (value) => _save(
                      ref,
                      config.copyWith(periodDaysBefore: value),
                    ),
                    onPickTime: () => _pickTime(context, ref, config),
                    timeText: _timeText(config.dailyHour, config.dailyMinute),
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    eyebrow: 'YOUR SPACE',
                    title: 'Data & devices',
                    subtitle: 'Sync, tracking and export.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.devices_rounded,
                          tint: palette.lavenderSoft,
                          title: 'Devices',
                          subtitle: 'Private sync',
                          onTap: () {
                            NylaHaptics.select();
                            context.push('/settings/sync');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.tune_rounded,
                          tint: palette.sageSoft,
                          title: 'Your logs',
                          subtitle: 'Tracking options',
                          onTap: () {
                            NylaHaptics.select();
                            context.push('/settings/logs');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.ios_share_rounded,
                          tint: palette.peachSoft,
                          title: 'Export',
                          subtitle: 'Make a copy',
                          onTap: () {
                            NylaHaptics.select();
                            context.push('/settings/export');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _EraseDataTile(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _toggleWithPermission(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
    NotificationConfig next,
  ) async {
    await NylaHaptics.select();
    if (enabled) {
      final service = await ref.read(notificationServiceProvider.future);
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allow notifications in your phone settings first.'),
            ),
          );
        }
        return;
      }
    }
    await _save(ref, next);
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    NotificationConfig config,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: config.dailyHour, minute: config.dailyMinute),
    );
    if (picked != null) {
      await NylaHaptics.select();
      await _save(
        ref,
        config.copyWith(dailyHour: picked.hour, dailyMinute: picked.minute),
      );
    }
  }

  Future<void> _save(WidgetRef ref, NotificationConfig config) =>
      ref.read(preferencesRepositoryProvider).setNotificationConfig(config);

  String _timeText(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({required this.value, required this.onChanged});

  final NylaAppearance value;
  final ValueChanged<NylaAppearance> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: palette.glass,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: palette.glassBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final mode in NylaAppearance.values)
                Expanded(
                  child: _AppearanceChoice(
                    value: mode,
                    selected: value == mode,
                    onTap: () => onChanged(mode),
                  ),
                ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Padding(
              key: ValueKey(value),
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 3),
              child: Text(
                switch (value) {
                  NylaAppearance.system => 'Changes with your phone automatically.',
                  NylaAppearance.light => 'Always use Nyla’s soft light palette.',
                  NylaAppearance.dark => 'Always use Nyla’s low-light palette.',
                },
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10.8,
                      color: palette.mutedInk,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final NylaAppearance value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    final icon = switch (value) {
      NylaAppearance.system => Icons.brightness_auto_rounded,
      NylaAppearance.light => Icons.light_mode_rounded,
      NylaAppearance.dark => Icons.dark_mode_rounded,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${value.label} appearance',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? palette.lavenderSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? palette.violet.withValues(alpha: 0.35) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? palette.violet : palette.mutedInk,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                value.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? palette.wine : palette.mutedInk,
                      fontSize: 11.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel({required this.privacy, required this.onPrivacyChanged});

  final NotificationPrivacy privacy;
  final ValueChanged<NotificationPrivacy> onPrivacyChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(21, 21, 18, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NylaColors.night, Color(0xFF392447), NylaColors.violet],
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: context.nyla.shadow,
              blurRadius: 34,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRIVACY',
                        style: TextStyle(
                          color: Color(0xFFD8CBE0),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Privacy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 19),
            const _AppLockTile(),
            const SizedBox(height: 10),
            _PrivacyRow(
              icon: Icons.visibility_off_rounded,
              title: 'Lock-screen text',
              subtitle: privacy == NotificationPrivacy.private
                  ? 'Hide period details'
                  : 'Show reminder details',
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<NotificationPrivacy>(
                  value: privacy,
                  dropdownColor: NylaColors.night,
                  iconEnabledColor: Colors.white,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: NotificationPrivacy.private,
                      child: Text('Private'),
                    ),
                    DropdownMenuItem(
                      value: NotificationPrivacy.contextual,
                      child: Text('Detailed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onPrivacyChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
      );
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.085),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFFE2D6E8), size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFD4C6DA),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing,
          ],
        ),
      );
}

class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({
    required this.config,
    required this.onPeriodApproaching,
    required this.onExpectedWindow,
    required this.onDailyLog,
    required this.onLeadTime,
    required this.onPickTime,
    required this.timeText,
  });

  final NotificationConfig config;
  final ValueChanged<bool> onPeriodApproaching;
  final ValueChanged<bool> onExpectedWindow;
  final ValueChanged<bool> onDailyLog;
  final ValueChanged<int> onLeadTime;
  final VoidCallback onPickTime;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
      decoration: BoxDecoration(
        color: palette.glass,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.glassBorder),
      ),
      child: Column(
        children: [
          const _NotificationAccessTile(),
          const _SoftDivider(),
          _ReminderRow(
            icon: Icons.upcoming_rounded,
            tint: palette.roseWash,
            title: 'Period approaching',
            subtitle: '${config.periodDaysBefore} days before the expected window',
            value: config.periodApproaching,
            onChanged: onPeriodApproaching,
          ),
          if (config.periodApproaching)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 5, 8),
              child: Row(
                children: [
                  Text(
                    '1d',
                    style: TextStyle(
                      color: palette.faintInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 7,
                      divisions: 6,
                      value: config.periodDaysBefore.toDouble(),
                      label: '${config.periodDaysBefore} days',
                      onChanged: (value) => onLeadTime(value.round()),
                    ),
                  ),
                  Text(
                    '7d',
                    style: TextStyle(
                      color: palette.faintInk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const _SoftDivider(),
          _ReminderRow(
            icon: Icons.blur_on_rounded,
            tint: palette.lavenderSoft,
            title: 'Expected window',
            subtitle: 'When the predicted range begins',
            value: config.expectedWindowStarts,
            onChanged: onExpectedWindow,
          ),
          const _SoftDivider(),
          _ReminderRow(
            icon: Icons.wb_twilight_rounded,
            tint: palette.sageSoft,
            title: 'Daily check-in',
            subtitle: config.dailyLogReminder ? timeText : 'Off',
            value: config.dailyLogReminder,
            onChanged: onDailyLog,
          ),
          if (config.dailyLogReminder)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 5, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onPickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 17),
                  label: Text('Time · $timeText'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationAccessTile extends ConsumerStatefulWidget {
  const _NotificationAccessTile();

  @override
  ConsumerState<_NotificationAccessTile> createState() => _NotificationAccessTileState();
}

class _NotificationAccessTileState extends ConsumerState<_NotificationAccessTile> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = await ref.read(notificationServiceProvider.future);
    final enabled = await service.notificationsEnabled();
    if (mounted) setState(() => _enabled = enabled ?? true);
  }

  Future<void> _request() async {
    if (_busy) return;
    await NylaHaptics.select();
    setState(() => _busy = true);
    final service = await ref.read(notificationServiceProvider.future);
    final granted = await service.requestPermission();
    final enabled = await service.notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enabled = enabled ?? granted;
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow notifications in your phone settings first.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _enabled == true;
    final palette = context.nyla;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.peachSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: palette.violet,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification access',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  _enabled == null
                      ? 'Checking…'
                      : ready
                          ? 'Allowed'
                          : 'Permission needed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.2),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (ready)
            Icon(Icons.check_circle_rounded, color: palette.expected, size: 22)
          else
            TextButton(onPressed: _request, child: const Text('Allow')),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: context.nyla.violet, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.2),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch.adaptive(value: value, onChanged: onChanged),
            ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(13, 14, 12, 13),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: palette.glass,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: palette.violet, size: 19),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.8),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 10.5,
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                color: context.nyla.violet,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.05,
              ),
            ),
            const SizedBox(height: 5),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      );
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 54),
        color: context.nyla.outline.withValues(alpha: 0.75),
      );
}

class _AppLockTile extends ConsumerStatefulWidget {
  const _AppLockTile();

  @override
  ConsumerState<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends ConsumerState<_AppLockTile> {
  bool? enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await ref.read(appLockServiceProvider).isEnabled();
    if (mounted) setState(() => enabled = value);
  }

  Future<void> _change(bool next) async {
    if (_busy) return;
    await NylaHaptics.select();
    setState(() => _busy = true);

    final appLock = ref.read(appLockServiceProvider);
    if (next) {
      final result = await appLock.authenticate(
        localizedReason: 'Turn on Nyla app lock',
      );
      if (!mounted) return;

      switch (result) {
        case AppLockAuthResult.success:
          break;
        case AppLockAuthResult.cancelled:
          setState(() => _busy = false);
          return;
        case AppLockAuthResult.unsupported:
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set up a phone screen lock first.')),
          );
          return;
        case AppLockAuthResult.failed:
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t confirm your phone lock.')),
          );
          return;
      }
    }

    final saved = await appLock.setEnabled(next);
    final stored = await appLock.isEnabled();
    if (!mounted) return;

    setState(() {
      enabled = stored;
      _busy = false;
    });
    if (saved && stored == next) {
      await NylaHaptics.confirm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App lock could not be saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _PrivacyRow(
        icon: Icons.lock_rounded,
        title: 'App lock',
        subtitle: enabled == true ? 'On' : 'Use your phone lock',
        trailing: _busy
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Transform.scale(
                scale: 0.88,
                child: Switch.adaptive(
                  value: enabled ?? false,
                  onChanged: enabled == null ? null : _change,
                  activeTrackColor: NylaColors.lavender,
                  activeThumbColor: Colors.white,
                ),
              ),
      );
}

enum _EraseScope { local, cloudAndLocal }

class _EraseDataTile extends ConsumerStatefulWidget {
  const _EraseDataTile();

  @override
  ConsumerState<_EraseDataTile> createState() => _EraseDataTileState();
}

class _EraseDataTileState extends ConsumerState<_EraseDataTile> {
  bool _busy = false;

  Future<void> _begin() async {
    if (_busy) return;
    await NylaHaptics.select();
    final sync = ref.read(syncServiceProvider);
    final hasSync = await sync.identity() != null;
    if (!mounted) return;

    final scope = await showDialog<_EraseScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase Nyla data'),
        content: Text(
          hasSync
              ? 'Choose what to erase. Other devices keep anything already saved on them.'
              : 'This permanently removes your Nyla history and private access information from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _EraseScope.local),
            child: const Text('This device only'),
          ),
          if (hasSync)
            FilledButton(
              onPressed: () => Navigator.pop(context, _EraseScope.cloudAndLocal),
              child: const Text('Synced copy + this device'),
            ),
        ],
      ),
    );
    if (scope == null || !mounted) return;

    final confirmed = await _confirm(scope);
    if (!confirmed || !mounted) return;
    await NylaHaptics.destructive();
    setState(() => _busy = true);

    try {
      if (scope == _EraseScope.cloudAndLocal) {
        await sync.deleteRemoteVault();
      }
      try {
        final notifications = await ref.read(notificationServiceProvider.future);
        await notifications.cancelAll();
      } catch (_) {
        // Notification cleanup must never prevent the user's data from being erased.
      }
      await ref.read(resetLocalDataProvider)();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = error.toString().contains('device_not_authorized')
          ? 'This device can no longer remove the shared sync copy. You can still erase this device only.'
          : 'Nyla could not finish that safely, so your local data was kept.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<bool> _confirm(_EraseScope scope) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: context.nyla.warning,
              size: 28,
            ),
            title: Text(
              scope == _EraseScope.cloudAndLocal
                  ? 'Remove the synced copy too?'
                  : 'Erase this device?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scope == _EraseScope.cloudAndLocal
                      ? 'This removes the shared sync copy and everything stored by Nyla on this device. Other devices keep anything already saved on them, but they will stop syncing with this copy.'
                      : 'This removes everything stored by Nyla on this device. Your shared sync copy and other devices are left alone.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Type ERASE to confirm.',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'ERASE'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  controller.text.trim() == 'ERASE',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.nyla.warning,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2D1712)
                      : Colors.white,
                ),
                child: const Text('Erase permanently'),
              ),
            ],
          ),
        ) ??
        false;
    controller.dispose();
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _busy ? null : _begin,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(15, 13, 14, 13),
          decoration: BoxDecoration(
            color: palette.glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.outline.withValues(alpha: 0.82)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.peachSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.warning,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erase data',
                      style: TextStyle(
                        color: palette.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Permanent removal',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.8),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right_rounded, color: palette.faintInk),
            ],
          ),
        ),
      ),
    );
  }
}
