import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/haptics/nyla_haptics.dart';
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
                        ? 'Keep period details off the lock screen'
                        : 'Show helpful reminder details',
                  ),
                  trailing: DropdownButton<NotificationPrivacy>(
                    value: config.privacy,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: NotificationPrivacy.private, child: Text('Private')),
                      DropdownMenuItem(value: NotificationPrivacy.contextual, child: Text('Detailed')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await NylaHaptics.select();
                      await _save(ref, config.copyWith(privacy: value));
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
                  subtitle: const Text('A reminder when your predicted range begins'),
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
          const _SectionTitle('Sync'),
          Card(
            child: ListTile(
              leading: const _IconBox(icon: Icons.cloud_outlined, tint: NylaColors.sage),
              title: const Text('Sync across devices'),
              subtitle: const Text('Keep your Nyla history in step on your trusted devices'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                NylaHaptics.select();
                context.push('/settings/sync');
              },
            ),
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Your data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const _IconBox(icon: Icons.tune_rounded, tint: NylaColors.lavender),
                  title: const Text('Custom logs'),
                  subtitle: const Text('Add or archive things that matter to you'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    NylaHaptics.select();
                    context.push('/settings/logs');
                  },
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                ListTile(
                  leading: const _IconBox(icon: Icons.ios_share_rounded, tint: NylaColors.peach),
                  title: const Text('Export'),
                  subtitle: const Text('Make a copy of your history'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    NylaHaptics.select();
                    context.push('/settings/export');
                  },
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                const ListTile(
                  leading: _IconBox(icon: Icons.info_outline_rounded, tint: NylaColors.lavender),
                  title: Text('Health guidance'),
                  subtitle: Text('Carefully reviewed with trusted medical sources'),
                ),
                const Divider(height: 1, indent: 18, endIndent: 18),
                const _EraseDataTile(),
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
    await NylaHaptics.select();
    if (enabled) {
      final service = await ref.read(notificationServiceProvider.future);
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications are off for Nyla. You can allow them in your phone settings.')),
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
      await NylaHaptics.select();
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
    await NylaHaptics.select();
    if (next) {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set up a screen lock on your phone before turning on Nyla lock.')),
          );
        }
        return;
      }
      try {
        final verified = await auth.authenticate(localizedReason: 'Unlock Nyla to confirm');
        if (!verified) return;
      } on LocalAuthException {
        return;
      }
    }
    await ref.read(secureVaultProvider).setAppLockEnabled(next);
    await NylaHaptics.confirm();
    if (mounted) setState(() => enabled = next);
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        secondary: const _IconBox(icon: Icons.lock_outline_rounded, tint: NylaColors.roseSoft),
        title: const Text('App lock'),
        subtitle: const Text('Use your phone lock whenever Nyla opens'),
        value: enabled ?? false,
        onChanged: enabled == null ? null : _change,
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirm(_EraseScope scope) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(scope == _EraseScope.cloudAndLocal ? 'Remove the synced copy too?' : 'Erase this device?'),
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
                const Text('Type ERASE to confirm.'),
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim() == 'ERASE'),
                style: FilledButton.styleFrom(backgroundColor: NylaColors.warning),
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
  Widget build(BuildContext context) => ListTile(
        leading: const _IconBox(icon: Icons.delete_outline_rounded, tint: NylaColors.peach),
        title: const Text('Erase data'),
        subtitle: const Text('Permanently remove data from this device or your shared sync copy'),
        trailing: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right_rounded),
        textColor: NylaColors.warning,
        iconColor: NylaColors.warning,
        onTap: _busy ? null : _begin,
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
