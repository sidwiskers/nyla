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
      appBar: AppBar(
        title: const Text('Private sync'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder(
        future: service.identity(),
        builder: (context, snapshot) {
          if (!service.endpointConfigured) return const _EndpointNotConfigured();
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
          }
          if (snapshot.hasError) {
            return _CenteredError(
              message: 'Nyla couldn’t open sync right now.',
              onRetry: _refresh,
            );
          }
          final identity = snapshot.data;
          return identity == null
              ? _buildNotConnected()
              : _buildConnected(identity.deviceId);
        },
      ),
    );
  }

  Widget _buildNotConnected() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
      children: [
        const _IntroCard(
          icon: Icons.sync_rounded,
          tint: NylaColors.sage,
          title: 'Keep Nyla in sync',
          body: 'Use the same Nyla history across your devices. Your private data stays protected automatically.',
        ),
        const SizedBox(height: 18),
        _ActionCard(
          icon: Icons.add_circle_outline_rounded,
          tint: NylaColors.roseSoft,
          title: 'Start sync',
          subtitle: 'Use this as your first Nyla device.',
          onTap: _busy ? null : _createVault,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.qr_code_scanner_rounded,
          tint: NylaColors.lavender,
          title: 'Connect existing sync',
          subtitle: 'Scan the code shown on another connected Nyla device.',
          onTap: _busy ? null : _scanPairing,
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.key_rounded,
          tint: NylaColors.peach,
          title: 'Recover sync',
          subtitle: 'Use your recovery code when you don’t have another device.',
          onTap: _busy ? null : _recover,
        ),
        if (_busy) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
        ],
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
          const _IntroCard(
            icon: Icons.check_rounded,
            tint: NylaColors.sage,
            title: 'Sync is on',
            body: 'Changes can stay up to date across your connected Nyla devices.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sync now',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _syncStatusText(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _syncNow,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sync'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.add_to_photos_outlined,
            tint: NylaColors.lavender,
            title: 'Add a device',
            subtitle: 'Show a QR for your other Nyla device to scan.',
            onTap: _busy ? null : _addDevice,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.key_rounded,
            tint: NylaColors.peach,
            title: 'Recovery code',
            subtitle: 'View or replace the code used to recover your sync.',
            onTap: _busy ? null : _recoveryCode,
          ),
          const SizedBox(height: 22),
          Text('Connected devices', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<SyncDevice>>(
            future: _devices,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.sync_problem_rounded),
                    title: const Text('Couldn’t load devices'),
                    subtitle: const Text('Tap to try again.'),
                    onTap: () => setState(() => _devices = _service.devices()),
                  ),
                );
              }
              final devices = snapshot.data ?? const <SyncDevice>[];
              return Card(
                child: Column(
                  children: [
                    for (var index = 0; index < devices.length; index++) ...[
                      _DeviceTile(
                        device: devices[index],
                        onRemove: devices[index].active && !devices[index].isCurrent
                            ? () => _removeDevice(devices[index])
                            : null,
                      ),
                      if (index != devices.length - 1)
                        const Divider(height: 1, indent: 18, endIndent: 18),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_message != null) _StatusMessage(_message!),
          const SizedBox(height: 12),
          Semantics(
            label: 'Current device ${_shortId(deviceId)}',
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _syncStatusText() {
    final run = _lastRun;
    if (run == null) return 'Ready';
    if (run.pending > 0) return '${run.pending} change${run.pending == 1 ? '' : 's'} waiting to sync';
    final moved = run.uploaded + run.downloaded;
    if (moved == 0) return 'Up to date';
    return 'Synced $moved change${moved == 1 ? '' : 's'}';
  }

  Future<void> _createVault() async {
    await _guard(() async {
      final setup = await _service.createVault();
      if (!mounted) return;
      final saved = await _showRecoveryCode(setup.recoveryCode);
      if (saved) await _service.confirmRecoveryCodeSaved();
      final result = await _service.syncNow();
      if (!mounted) return;
      setState(() {
        _lastRun = result;
        _message = saved
            ? 'Sync is ready.'
            : 'Sync is ready. You can save your recovery code anytime from this screen.';
      });
      _refresh();
    });
  }

  Future<void> _syncNow() async {
    await _guard(() async {
      final result = await _service.syncNow();
      if (!mounted) return;
      setState(() {
        _lastRun = result;
        _message = result.pending == 0 ? 'Up to date.' : 'Nyla will retry the remaining changes automatically.';
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
      if (!mounted || !paired) return;
      setState(() {
        _message = 'Device connected.';
        _devices = _service.devices();
      });
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
      if (mounted) setState(() => _message = 'Connecting…');
      final state = await _service.joinPairing(encodedCode);

      for (var attempt = 0; attempt < 60; attempt++) {
        if (!mounted) return;
        final complete = await _service.completePairing(state);
        if (complete) {
          final result = await _service.syncNow();
          if (!mounted) return;
          setState(() {
            _lastRun = result;
            _message = 'Connected. Your Nyla data is syncing now.';
            _devices = _service.devices();
          });
          _refresh();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }

      throw const SyncTransportException('pairing_timed_out');
    });
  }

  Future<void> _recover() async {
    final code = await _textCodeDialog(
      title: 'Recovery code',
      hint: 'NYLA1.…',
      description: 'Paste or enter the recovery code you saved earlier.',
    );
    if (code == null || code.trim().isEmpty) return;

    await _guard(() async {
      final setup = await _service.recoverVault(code);
      if (!mounted) return;
      final saved = await _showRecoveryCode(setup.recoveryCode);
      if (saved) await _service.confirmRecoveryCodeSaved();
      final result = await _service.syncNow();
      if (!mounted) return;
      setState(() {
        _lastRun = result;
        _message = saved
            ? 'Sync recovered.'
            : 'Sync recovered. Save the new recovery code when you can.';
        _devices = _service.devices();
      });
      _refresh();
    });
  }

  Future<void> _removeDevice(SyncDevice device) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove this device?'),
            content: const Text(
              'It will stop syncing with Nyla. Your other connected devices will keep working normally.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove device'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    await _guard(() async {
      final result = await _service.rotateAndRevoke(device.deviceId);
      if (!mounted) return;
      final saved = await _showRecoveryCode(result.recoveryCode);
      if (saved) await _service.confirmRecoveryCodeSaved();
      if (!mounted) return;
      setState(() {
        _devices = _service.devices();
        _message = saved
            ? 'Device removed.'
            : 'Device removed. Save the new recovery code when you can.';
      });
    });
  }

  Future<void> _recoveryCode() async {
    await _guard(() async {
      final pending = await _service.pendingRecoveryCode();
      final code = pending ?? await _service.rotateRecoveryCode();
      if (!mounted) return;
      final saved = await _showRecoveryCode(code);
      if (saved) {
        await _service.confirmRecoveryCodeSaved();
        if (mounted) setState(() => _message = 'Recovery code saved.');
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
              decoration: InputDecoration(
                hintText: hint,
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) controller.text = data!.text!.trim();
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _showRecoveryCode(String code) async {
    var copied = false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Recovery code'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keep this somewhere safe. You only need it if you lose access to all connected devices.',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NylaColors.canvas,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        code,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        setDialogState(() => copied = true);
                      },
                      icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded),
                      label: Text(copied ? 'Copied' : 'Copy code'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('I’ve saved it'),
                ),
              ],
            ),
          ),
        ) ??
        false;
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
      if (mounted) setState(() => _message = 'That Nyla code isn’t valid.');
    } on SyncTransportException catch (error) {
      if (mounted) setState(() => _message = _friendlySyncError(error.message));
    } catch (_) {
      if (mounted) setState(() => _message = 'Couldn’t connect right now. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _devices = null);
  }

  String _friendlySyncError(String code) => switch (code) {
        'sync_endpoint_not_configured' => 'Sync isn’t available in this build.',
        'sync_already_configured' => 'This device is already connected.',
        'sync_not_configured' => 'Start sync on this device first.',
        'recovery_not_found' => 'That recovery code is no longer active.',
        'recovery_rate_limited' => 'Too many recovery attempts. Try again later.',
        'device_not_authorized' => 'This device is no longer connected to that sync.',
        'vault_key_epoch_changed' => 'Another device changed the shared sync state. Try syncing again.',
        'pairing_timed_out' => 'The other device didn’t respond in time. Keep its QR open and try once more.',
        'not_found' => 'That pairing code has expired. Create a new one on the other device.',
        _ => 'Couldn’t connect right now. Try again.',
      };

  String _shortId(String id) =>
      id.length <= 10 ? id : '${id.substring(0, 5)}…${id.substring(id.length - 4)}';
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
  String _status = 'Waiting for your other device…';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _check());
    unawaited(_check());
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
        _status = status.joined ? 'Connecting…' : 'Waiting for your other device…';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Still waiting…');
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
      title: const Text('Add a device'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'On your other device, open Nyla → Private sync → Connect existing sync, then scan this code.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: QrImageView(data: encoded, size: 238, gapless: false),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: encoded));
                if (mounted) setState(() => _copied = true);
              },
              icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
              label: Text(_copied ? 'Pairing code copied' : 'Copy pairing code'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PairingScannerScreen extends StatefulWidget {
  const _PairingScannerScreen();

  @override
  State<_PairingScannerScreen> createState() => _PairingScannerScreenState();
}

class _PairingScannerScreenState extends State<_PairingScannerScreen> {
  bool _handled = false;

  void _detected(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && _looksLikePairingCode(value)) {
        _handled = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  bool _looksLikePairingCode(String value) =>
      value.toUpperCase().startsWith('${PairingCode.prefix}.');

  Future<void> _manual() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use pairing code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the code from your other Nyla device.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'NYLAP1.…',
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) controller.text = data!.text!.trim();
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!_looksLikePairingCode(value)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('That doesn’t look like a Nyla pairing code.')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _manual,
            child: const Text('Use code'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _detected,
            tapToFocus: true,
            useAppLifecycleState: true,
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              onUseCode: _manual,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 248,
                height: 248,
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
                padding: EdgeInsets.fromLTRB(26, 26, 26, 34),
                child: Text(
                  'Point the camera at the QR on your other Nyla device.',
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

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onUseCode});

  final MobileScannerException error;
  final VoidCallback onUseCode;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_rounded : Icons.qr_code_2_rounded,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                denied ? 'Camera access is off' : 'Camera isn’t available',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'You can still connect using the pairing code from your other device.'
                    : 'Use the pairing code instead.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD2D2D2)),
              ),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onUseCode,
                child: const Text('Use pairing code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onRemove});

  final SyncDevice device;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final label = device.isCurrent ? 'This device' : 'Connected device';
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
        child: Icon(
          device.isCurrent ? Icons.smartphone_rounded : Icons.devices_rounded,
          size: 20,
        ),
      ),
      title: Text(label),
      subtitle: Text('$id${device.revokedMs == null ? '' : ' · removed'}'),
      trailing: device.isCurrent
          ? const Icon(Icons.check_circle_rounded, color: NylaColors.rose)
          : onRemove == null
              ? null
              : IconButton(
                  tooltip: 'Remove device',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
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
            title: 'Sync isn’t available in this build',
            body: 'Your Nyla data on this device still works normally.',
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
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

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
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(17),
                ),
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
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}
