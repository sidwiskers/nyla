import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sync_core/sync_core.dart';

import '../../core/sync/sync_http_client.dart';
import '../../core/sync/sync_service.dart';
import '../../core/theme/nyla_theme.dart';
import '../../providers.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _busy = false;
  String? _message;
  SyncRunResult? _lastRun;
  Future<List<SyncDevice>>? _devices;

  SyncService get _service => ref.read(syncServiceProvider);

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(syncServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Private sync'), backgroundColor: Colors.transparent),
      body: FutureBuilder(
        future: service.identity(),
        builder: (context, snapshot) {
          if (!service.endpointConfigured) return const _EndpointNotConfigured();
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
          }
          if (snapshot.hasError) {
            return _CenteredError(message: 'Nyla could not read the local sync identity.', onRetry: _refresh);
          }
          final identity = snapshot.data;
          return identity == null ? _buildNotConnected() : _buildConnected(identity.deviceId);
        },
      ),
    );
  }

  Widget _buildNotConnected() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
      children: [
        _IntroCard(
          icon: Icons.shield_outlined,
          tint: NylaColors.sage,
          title: 'Sync without giving up your privacy.',
          body:
              'Nyla encrypts changes on this device. The relay only coordinates signed ciphertext; it never receives the key that can read your menstrual history.',
        ),
        const SizedBox(height: 18),
        _ActionCard(
          icon: Icons.cloud_done_outlined,
          tint: NylaColors.roseSoft,
          title: 'Create a private sync vault',
          subtitle: 'Keep this device as the first trusted device.',
          onTap: _busy ? null : _createVault,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.qr_code_scanner_rounded,
          tint: NylaColors.lavender,
          title: 'Connect to another device',
          subtitle: 'Scan the one-time QR shown by a device you already trust.',
          onTap: _busy ? null : _scanPairing,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.key_rounded,
          tint: NylaColors.peach,
          title: 'Recover with your recovery code',
          subtitle: 'Use this only when an existing trusted device is unavailable.',
          onTap: _busy ? null : _recover,
        ),
        if (_message != null) _StatusMessage(_message!),
      ],
    );
  }

  Widget _buildConnected(String deviceId) {
    _devices ??= _service.devices();
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _devices = _service.devices());
        await _devices;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          _IntroCard(
            icon: Icons.lock_rounded,
            tint: NylaColors.sage,
            title: 'Your vault is connected.',
            body: 'Readable health data and encryption keys stay on trusted devices. Sync can work even when your other devices are offline.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Sync now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _syncNow,
                        icon: _busy
                            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Sync'),
                      ),
                    ],
                  ),
                  if (_lastRun != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _lastRun!.pending == 0
                          ? '${_lastRun!.uploaded} uploaded · ${_lastRun!.downloaded} received · up to date'
                          : '${_lastRun!.uploaded} uploaded · ${_lastRun!.downloaded} received · ${_lastRun!.pending} still pending',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.add_to_photos_outlined,
            tint: NylaColors.lavender,
            title: 'Add another device',
            subtitle: 'Show a short-lived QR. Its secret never needs to be typed into a server.',
            onTap: _busy ? null : _addDevice,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.key_rounded,
            tint: NylaColors.peach,
            title: 'Recovery code',
            subtitle: 'View an unsaved code or replace the current recovery code.',
            onTap: _busy ? null : _recoveryCode,
          ),
          const SizedBox(height: 22),
          Text('Trusted devices', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<SyncDevice>>(
            future: _devices,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_rounded),
                    title: const Text('Could not load devices'),
                    subtitle: const Text('Pull down or tap to try again.'),
                    onTap: () => setState(() => _devices = _service.devices()),
                  ),
                );
              }
              final devices = snapshot.data ?? const <SyncDevice>[];
              return Card(
                child: Column(
                  children: [
                    for (var i = 0; i < devices.length; i++) ...[
                      _DeviceTile(device: devices[i]),
                      if (i != devices.length - 1) const Divider(height: 1, indent: 18, endIndent: 18),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_message != null) _StatusMessage(_message!),
          const SizedBox(height: 12),
          Text(
            'This device · ${_shortId(deviceId)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _createVault() async {
    await _guard(() async {
      final setup = await _service.createVault();
      final saved = await _showRecoveryVerification(setup.recoveryCode);
      if (!saved) {
        setState(() => _message = 'Your vault exists, but Nyla will keep asking you to save its recovery code.');
      } else {
        await _service.confirmRecoveryCodeSaved();
        final result = await _service.syncNow();
        setState(() {
          _lastRun = result;
          _message = 'Private sync is ready.';
        });
      }
      _refresh();
    });
  }

  Future<void> _syncNow() async {
    await _guard(() async {
      final result = await _service.syncNow();
      setState(() {
        _lastRun = result;
        _message = result.pending == 0 ? 'Everything is synced.' : '${result.pending} encrypted changes will retry.';
        _devices = _service.devices();
      });
    });
  }

  Future<void> _addDevice() async {
    await _guard(() async {
      final code = await _service.createPairingInvite();
      if (!mounted) return;
      final paired = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => _PairingInviteDialog(service: _service, code: code),
          ) ??
          false;
      if (paired && mounted) {
        setState(() {
          _message = 'The new device is trusted and can now sync.';
          _devices = _service.devices();
        });
      }
    });
  }

  Future<void> _scanPairing() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _PairingScannerScreen()),
    );
    if (!mounted || code == null) return;
    await _joinPairing(code);
  }

  Future<void> _joinPairing(String encodedCode) async {
    await _guard(() async {
      final state = await _service.joinPairing(encodedCode);
      if (!mounted) return;
      final completed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => _PairingJoinDialog(service: _service, state: state),
          ) ??
          false;
      if (completed) {
        final result = await _service.syncNow();
        if (mounted) {
          setState(() {
            _lastRun = result;
            _message = 'This device is now connected.';
            _devices = _service.devices();
          });
          _refresh();
        }
      }
    });
  }

  Future<void> _recover() async {
    final code = await _textCodeDialog(
      title: 'Recovery code',
      hint: 'NYLA1.…',
      description: 'Enter the recovery code you saved when private sync was created.',
    );
    if (code == null || code.trim().isEmpty) return;
    await _guard(() async {
      final setup = await _service.recoverVault(code);
      if (!mounted) return;
      final saved = await _showRecoveryVerification(setup.recoveryCode);
      if (saved) await _service.confirmRecoveryCodeSaved();
      final result = await _service.syncNow();
      if (mounted) {
        setState(() {
          _lastRun = result;
          _message = saved
              ? 'Recovery succeeded. The old recovery code has been replaced.'
              : 'Recovery succeeded. Save the new recovery code before relying on recovery again.';
          _devices = _service.devices();
        });
        _refresh();
      }
    });
  }

  Future<void> _recoveryCode() async {
    await _guard(() async {
      final pending = await _service.pendingRecoveryCode();
      final code = pending ?? await _service.rotateRecoveryCode();
      if (!mounted) return;
      final saved = await _showRecoveryVerification(code);
      if (saved) {
        await _service.confirmRecoveryCodeSaved();
        if (mounted) setState(() => _message = 'Recovery code confirmed and saved by you.');
      } else if (mounted) {
        setState(() => _message = 'Nyla will keep this recovery code available until you confirm it.');
      }
    });
  }

  Future<String?> _textCodeDialog({
    required String title,
    required String hint,
    required String description,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _showRecoveryVerification(String code) async {
    final suffix = code.length >= 8 ? code.substring(code.length - 8) : code;
    final controller = TextEditingController();
    var copied = false;
    final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Save your recovery code'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nyla cannot recover this secret for you. Keep it somewhere only you can access. A person with this code can authorize a new device.',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: NylaColors.canvas, borderRadius: BorderRadius.circular(16)),
                      child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        setDialogState(() => copied = true);
                      },
                      icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
                      label: Text(copied ? 'Copied' : 'Copy code'),
                    ),
                    const SizedBox(height: 12),
                    Text('To confirm, enter the last 8 characters: $suffix'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(hintText: 'Last 8 characters'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim() == suffix) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Those characters do not match the recovery code.')),
                      );
                    }
                  },
                  child: const Text('Confirm saved'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    controller.dispose();
    return result;
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on FormatException {
      if (mounted) setState(() => _message = 'That Nyla code is not valid.');
    } on SyncTransportException catch (error) {
      if (mounted) setState(() => _message = _friendlySyncError(error.message));
    } catch (_) {
      if (mounted) setState(() => _message = 'Private sync could not complete that action safely.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _devices = null);
  }

  String _friendlySyncError(String code) => switch (code) {
        'sync_endpoint_not_configured' => 'Private sync is not configured in this build.',
        'sync_already_configured' => 'This device is already connected to a private sync vault.',
        'sync_not_configured' => 'Set up private sync first.',
        'recovery_not_found' => 'That recovery code is no longer active.',
        'recovery_rate_limited' => 'Too many recovery attempts. Try again later.',
        'device_not_authorized' => 'This device is no longer authorized for that vault.',
        'vault_key_epoch_changed' => 'The vault security key changed on another device. Nyla stopped instead of risking an unsafe merge.',
        _ => 'Private sync could not complete ($code).',
      };

  String _shortId(String id) => id.length <= 10 ? id : '${id.substring(0, 5)}…${id.substring(id.length - 4)}';
}

class _PairingInviteDialog extends StatefulWidget {
  const _PairingInviteDialog({required this.service, required this.code});

  final SyncService service;
  final PairingCode code;

  @override
  State<_PairingInviteDialog> createState() => _PairingInviteDialogState();
}

class _PairingInviteDialogState extends State<_PairingInviteDialog> {
  Timer? _timer;
  bool _checking = false;
  bool _copied = false;
  String _status = 'Waiting for the other device to scan…';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final status = await widget.service.progressPairingInvite(widget.code);
      if (!mounted) return;
      if (status.consumed) {
        _timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _status = status.authorized
            ? 'Device found. Finishing the encrypted handoff…'
            : status.joined
                ? 'Device found. Authorizing securely…'
                : 'Waiting for the other device to scan…';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not check pairing. Keep this open and Nyla will retry.');
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encoded = widget.code.toString();
    return AlertDialog(
      title: const Text('Add a trusted device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('On the other device, open Private sync and scan this one-time QR.'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: QrImageView(data: encoded, size: 220, gapless: false),
            ),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Can’t scan?'),
              children: [
                SelectableText(encoded, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: encoded));
                    if (mounted) setState(() => _copied = true);
                  },
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
                  label: Text(_copied ? 'Copied' : 'Copy pairing code'),
                ),
              ],
            ),
            const Text(
              'Treat this QR like a temporary secret. Close this window if you did not initiate the pairing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: NylaColors.mutedInk),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))],
    );
  }
}

class _PairingJoinDialog extends StatefulWidget {
  const _PairingJoinDialog({required this.service, required this.state});

  final SyncService service;
  final PairingJoinState state;

  @override
  State<_PairingJoinDialog> createState() => _PairingJoinDialogState();
}

class _PairingJoinDialogState extends State<_PairingJoinDialog> {
  Timer? _timer;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    unawaited(_check());
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final complete = await widget.service.completePairing(widget.state);
      if (complete && mounted) {
        _timer?.cancel();
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'The secure handoff could not be completed.');
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Connecting securely'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.4),
            const SizedBox(height: 18),
            Text(
              _error ?? 'Keep this open for a moment. Your trusted device is encrypting the vault key specifically for this pairing.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))],
      );
}

class _PairingScannerScreen extends StatefulWidget {
  const _PairingScannerScreen();

  @override
  State<_PairingScannerScreen> createState() => _PairingScannerScreenState();
}

class _PairingScannerScreenState extends State<_PairingScannerScreen> {
  late final MobileScannerController _scanner;
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    _subscription = _scanner.barcodes.listen(_detected);
  }

  void _detected(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.toUpperCase().startsWith('${PairingCode.prefix}.')) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  Future<void> _manual() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter pairing code'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'NYLAP1.…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) Navigator.pop(context, result);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan trusted device'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [TextButton(onPressed: _manual, child: const Text('Enter code'))],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scanner),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'Only scan a QR shown inside Nyla on a device you trust.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final SyncDevice device;

  @override
  Widget build(BuildContext context) {
    final label = device.isCurrent ? 'This device' : 'Trusted device';
    final id = device.deviceId.length <= 10
        ? device.deviceId
        : '${device.deviceId.substring(0, 5)}…${device.deviceId.substring(device.deviceId.length - 4)}';
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: device.active ? NylaColors.sage : NylaColors.peach,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(device.isCurrent ? Icons.smartphone_rounded : Icons.devices_rounded, size: 20),
      ),
      title: Text(label),
      subtitle: Text('$id${device.revokedMs == null ? '' : ' · revoked'}'),
      trailing: device.isCurrent ? const Icon(Icons.check_circle_rounded, color: NylaColors.rose) : null,
    );
  }
}

class _EndpointNotConfigured extends StatelessWidget {
  const _EndpointNotConfigured();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: const [
          _IntroCard(
            icon: Icons.cloud_off_outlined,
            tint: NylaColors.peach,
            title: 'Private sync is not enabled in this build.',
            body: 'Your local encrypted data works normally. A production build enables sync by providing its HTTPS Nyla relay endpoint at build time.',
          ),
        ],
      );
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.icon, required this.tint, required this.title, required this.body});

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(17)),
                child: Icon(icon),
              ),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(body),
            ],
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 21),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      );
}
