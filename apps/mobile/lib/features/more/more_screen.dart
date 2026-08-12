import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics/nyla_haptics.dart';
import '../../core/theme/nyla_theme.dart';
import '../../widgets/nyla_page.dart';
import '../../widgets/nyla_ui.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) => NylaPage(
        title: 'More',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Group(
              children: [
                _Row(
                  icon: Icons.notifications_none_rounded,
                  tint: NylaColors.lavenderSoft,
                  title: 'Reminders',
                  onTap: () => _push(context, '/settings'),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.cloud_outlined,
                  tint: NylaColors.lavenderSoft,
                  title: 'Sync',
                  subtitle: 'Private across your devices',
                  onTap: () => _push(context, '/settings/sync'),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.lock_outline_rounded,
                  tint: NylaColors.peachSoft,
                  title: 'App Lock',
                  onTap: () => _push(context, '/settings'),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.ios_share_rounded,
                  tint: NylaColors.lavenderSoft,
                  title: 'Export Data',
                  onTap: () => _push(context, '/settings/export'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Group(
              children: [
                _Row(
                  icon: Icons.auto_stories_outlined,
                  tint: NylaColors.sageSoft,
                  title: 'Tips & Care',
                  onTap: () => _push(context, '/learn'),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.tune_rounded,
                  tint: NylaColors.sageSoft,
                  title: 'Your Logs',
                  onTap: () => _push(context, '/settings/logs'),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.info_outline_rounded,
                  tint: NylaColors.lavenderSoft,
                  title: 'About Nyla',
                  subtitle: '1.0.0',
                  onTap: () => _about(context),
                ),
                const NylaHairline(margin: EdgeInsets.only(left: 56)),
                _Row(
                  icon: Icons.help_outline_rounded,
                  tint: NylaColors.lavenderSoft,
                  title: 'Help & Support',
                  onTap: () => _help(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: NylaColors.faintInk),
                  SizedBox(width: 7),
                  Text(
                    'Private by design',
                    style: TextStyle(
                      color: NylaColors.faintInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 84),
          ],
        ),
      );

  void _push(BuildContext context, String route) {
    NylaHaptics.select();
    context.push(route);
  }

  void _about(BuildContext context) {
    NylaHaptics.select();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _InfoSheet(
        icon: NylaBloomMark(size: 50),
        title: 'Nyla',
        body: 'A quiet place to understand your cycle, notice patterns, and keep the details that matter to you.',
      ),
    );
  }

  void _help(BuildContext context) {
    NylaHaptics.select();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _InfoSheet(
        icon: NylaIconToken(
          icon: Icons.favorite_outline_rounded,
          size: 50,
          background: NylaColors.roseWash,
          foreground: NylaColors.rose,
        ),
        title: 'Here when you need it',
        body: 'Use Tips & Care for guidance, or open Settings whenever you want to change reminders, privacy, sync, or your logs.',
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NylaPaperSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shadow: false,
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NylaPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            children: [
              NylaIconToken(icon: icon, background: tint, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10.8)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: NylaColors.faintInk, size: 20),
            ],
          ),
        ),
      );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.icon, required this.title, required this.body});

  final Widget icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25)),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
}
