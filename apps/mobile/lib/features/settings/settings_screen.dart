import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/notifications/notification_config.dart';
import '../../core/theme/nyla_theme.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(notificationConfigProvider);
    final config = configAsync.value ?? const NotificationConfig();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          const _SectionTitle('Privacy'),
          Card(
            child: Column(
              children: [
                _AppLockTile(),
                const Divider(height: 1, indent: 18, endIndent: 18),
                ListTile(
                  leading: const _IconBox(icon: Icons.visibility_off_rounded, tint: NylaColors.lavender),
                  title: const Text('Notification wording'),
                  subtitle: Text(
                    config.privacy == NotificationPrivacy.private
                        ? 'Hide period context on the lock screen'
                        : 'Show useful reminder context',
                  ),
                  trailing: DropdownButton<NotificationPrivacy>(
                    value: config.privacy,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: NotificationPrivacy.private, child: Text('Private')),
                      DropdownMenuItem(value: NotificationPrivacy.contextual, child: Text('Context')),
                    ],
                    onChanged: (value) {
                      if (value != null) _save(ref, config.copyWith(privacy: value));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Reminders'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Period approaching'),
                  subtitle: Text('${config.periodDaysBefore} days before the earliest expected day'),
                  value: config.periodApproaching,
                  onChanged: (enabled) => _toggleWithPermission(
                    context,
                    ref,
                    enabled,
                    config.copyWith(periodApproaching: enabled),
                  ),
                ),
                if (config.periodApproaching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        const Text('Lead time'),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 7,
                            divisions: 6,
                            value: config.periodDaysBefore.toDouble(),
                            label: '${config.periodDaysBefore} days',
                            onChanged: (value) => _save(ref, config.copyWith(periodDaysBefore: value.round())),
                          ),
                        ),
                        Text('${config.periodDaysBefore}d'),
                      ],
                    ),
                  ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                SwitchListTile.adaptive(
                  title: const Text('Expected window starts'),
                  subtitle: const Text('A reminder when the predicted range begins'),
                  value: config.expectedWindowStarts,
                  onChanged: (enabled) => _toggleWithPermission(
                    context,
                    ref,
                    enabled,
                    config.copyWith(expectedWindowStarts: enabled),
                  ),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                SwitchListTile.adaptive(
                  title: const Text('Daily check-in'),
                  subtitle: Text(_timeText(config.dailyHour, config.dailyMinute)),
                  value: config.dailyLogReminder,
                  onChanged: (enabled) => _toggleWithPermission(
                    context,
                    ref,
                    enabled,
                    config.copyWith(dailyLogReminder: enabled),
                  ),
                ),
                if (config.dailyLogReminder)
                  ListTile(
                    title: const Text('Check-in time'),
                    trailing: TextButton(
                      onPressed: () => _pickTime(context, ref, config),
                      child: Text(_timeText(config.dailyHour, config.dailyMinute)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Private sync'),
          Card(
            child: ListTile(
              leading: const _IconBox(icon: Icons.cloud_outlined, tint: NylaColors.sage),
              title: const Text('Encrypted multi-device sync'),
              subtitle: const Text('Local data remains readable only on your devices.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync setup is being wired to the encrypted vault service.')),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Your data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const _IconBox(icon: Icons.ios_share_rounded, tint: NylaColors.peach),
                  title: const Text('Export'),
                  subtitle: const Text('Create a user-controlled copy of your history'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export format is being connected to the encrypted local store.')),
                  ),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                const ListTile(
                  leading: _IconBox(icon: Icons.info_outline_rounded, tint: NylaColors.lavender),
                  title: Text('Medical content'),
                  subtitle: Text('Source-backed, versioned and reviewed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWithPermission(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
    NotificationConfig next,
  ) async {
    if (enabled) {
      final service = await ref.read(notificationServiceProvider.future);
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission was not granted.')),
          );
        }
        return;
      }
    }
    await _save(ref, next);
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, NotificationConfig config) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: config.dailyHour, minute: config.dailyMinute),
    );
    if (picked != null) {
      await _save(ref, config.copyWith(dailyHour: picked.hour, dailyMinute: picked.minute));
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

class _AppLockTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends ConsumerState<_AppLockTile> {
  bool? enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await ref.read(secureVaultProvider).isAppLockEnabled();
    if (mounted) setState(() => enabled = value);
  }

  Future<void> _change(bool next) async {
    if (next) {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set up a device screen lock before enabling Nyla lock.')),
          );
        }
        return;
      }
      try {
        final verified = await auth.authenticate(localizedReason: 'Confirm device lock for Nyla');
        if (!verified) return;
      } on LocalAuthException {
        return;
      }
    }
    await ref.read(secureVaultProvider).setAppLockEnabled(next);
    if (mounted) setState(() => enabled = next);
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        secondary: const _IconBox(icon: Icons.lock_outline_rounded, tint: NylaColors.roseSoft),
        title: const Text('App lock'),
        subtitle: const Text('Require your device authentication when Nyla opens'),
        value: enabled ?? false,
        onChanged: enabled == null ? null : _change,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 20),
      );
}
