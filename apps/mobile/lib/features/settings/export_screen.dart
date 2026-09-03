import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/export/data_export_service.dart';
import '../../core/theme/nyla_theme.dart';
import '../../core/theme/nyla_typography.dart';
import '../../providers.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final json = await DataExportService(ref.read(databaseProvider)).buildJson();
      final now = DateTime.now().toUtc();
      final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await SharePlus.instance.share(
        ShareParams(
          title: 'Nyla data export',
          text: 'Your Nyla health-data export.',
          files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
          fileNameOverrides: ['nyla-export-$date.json'],
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Nyla could not create the export safely.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.nyla;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export your data'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.peach,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.ios_share_rounded,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your history belongs to you.',
                    style: NylaTypography.display(
                      Theme.of(context).textTheme.headlineMedium,
                      size: 29,
                      opticalSize: 34,
                      weight: FontWeight.w600,
                      height: 1.04,
                      letterSpacing: -0.28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create a complete readable copy of your periods, daily logs, notes, custom logs and preferences. Sync keys, device credentials and encrypted-relay metadata are never included.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_open_rounded, color: palette.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The exported JSON is intentionally readable so you can keep or move it. Once shared outside Nyla, its privacy depends on where you save or send it.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.warning)),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(_busy ? 'Preparing…' : 'Create export'),
          ),
        ],
      ),
    );
  }
}
