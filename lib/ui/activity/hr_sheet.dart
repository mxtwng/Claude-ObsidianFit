/// Bottom sheet for finding and connecting a BLE heart-rate monitor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../services/location_ble_service.dart';
import '../theme/app_theme.dart';

Future<void> showHeartRateSheet(
  BuildContext context,
  HeartRateMonitor monitor,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HeartRateSheet(monitor: monitor),
  );
}

class _HeartRateSheet extends StatefulWidget {
  const _HeartRateSheet({required this.monitor});

  final HeartRateMonitor monitor;

  @override
  State<_HeartRateSheet> createState() => _HeartRateSheetState();
}

class _HeartRateSheetState extends State<_HeartRateSheet> {
  String? _error;

  HeartRateMonitor get _m => widget.monitor;

  @override
  void initState() {
    super.initState();
    if (_m.state == HrConnectionState.disconnected) _scan();
  }

  @override
  void dispose() {
    _m.stopScan().catchError((Object _) {});
    super.dispose();
  }

  Future<void> _scan() async {
    final error = await _m.startScan();
    if (mounted) setState(() => _error = error);
  }

  static String _nameOf(ScanResult r) {
    final adv = r.advertisementData.advName;
    if (adv.isNotEmpty) return adv;
    final platform = r.device.platformName;
    return platform.isNotEmpty ? platform : 'Unnamed monitor';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _m,
      builder: (context, _) {
        final linked = _m.state != HrConnectionState.disconnected;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Heart rate monitor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (linked) _connected(context) else _scanner(context),
            ],
          ),
        );
      },
    );
  }

  Widget _connected(BuildContext context) {
    final status = switch (_m.state) {
      HrConnectionState.connected => 'Connected',
      HrConnectionState.connecting => 'Connecting…',
      HrConnectionState.reconnecting => 'Signal lost, reconnecting…',
      HrConnectionState.disconnected => 'Disconnected',
    };
    final bpm = _m.freshBpm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _m.deviceName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        Text(status, style: const TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            bpm == null ? '--' : '$bpm',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
        ),
        const Center(
          child: Text('bpm', style: TextStyle(color: AppColors.textDim)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _m.disconnect,
            child: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }

  Widget _scanner(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
        StreamBuilder<bool>(
          stream: _m.isScanning,
          initialData: false,
          builder: (context, scanning) {
            final busy = scanning.data ?? false;
            return Row(
              children: [
                Expanded(
                  child: Text(
                    busy
                        ? 'Searching for monitors…'
                        : 'Put on your strap, then scan.',
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(onPressed: _scan, child: const Text('Scan')),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        StreamBuilder<List<ScanResult>>(
          stream: _m.scanResults,
          initialData: const [],
          builder: (context, snap) {
            final results = [...?snap.data]
              ..sort((a, b) => b.rssi.compareTo(a.rssi));
            if (results.isEmpty) return const SizedBox(height: 24);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.favorite, color: AppColors.danger),
                      title: Text(_nameOf(r)),
                      subtitle: Text('Signal ${r.rssi} dBm'),
                      onTap: () {
                        _m.connect(r.device);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
