import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

class BluetoothSyncPage extends StatefulWidget {
  const BluetoothSyncPage({super.key, required this.isManager});
  final bool isManager;
  @override
  State<BluetoothSyncPage> createState() => _BluetoothSyncPageState();
}

class _BluetoothSyncPageState extends State<BluetoothSyncPage> {
  final Nearby nearby = Nearby();
  final Strategy strategy = Strategy.P2P_CLUSTER;
  // Both devices must use the same Nearby Connections service ID.
  static const String _serviceId = 'طلبات-المزامنة';
  final Map<String, String> endpoints = {};
  String status = 'اختر وضع المزامنة ثم اجعل الجهازين قريبين';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    
  }

  Future<bool> _ensureBluetoothPermissions() async {
    // Android 11 (API 30) and older require runtime location permission
    // for BLE discovery. Android 12+ uses the Nearby Devices permissions.
    final permissions = <Permission>[
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ];
    final results = await permissions.request();
    final granted = results.values.every((status) => status.isGranted);
    if (!granted && mounted) {
      final permanentlyDenied = results.values.any((status) => status.isPermanentlyDenied);
      setState(() => status = permanentlyDenied
          ? 'صلاحيات البلوتوث مرفوضة نهائيًا. افتح إعدادات التطبيق واسمح بالبلوتوث.'
          : 'يرجى السماح بصلاحيات البلوتوث لتشغيل المزامنة.');
    }
    return granted;
  }

  Future<void> _receivePayload(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
    try {
      await AppDb.instance.importSnapshot(utf8.decode(payload.bytes!));
      if (mounted) setState(() => status = 'تم استقبال البيانات ودمجها محليًا');
    } catch (_) {
      if (mounted) setState(() => status = 'تعذر قراءة البيانات المستلمة');
    }
  }

  Future<void> _sendSnapshot(String endpointId) async {
    final snapshot = await AppDb.instance.exportSnapshot();
    await nearby.sendBytesPayload(endpointId, utf8.encode(snapshot));
  }

  Future<void> _startManager() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = 'جاري التحقق من الصلاحيات…';
    });
    try {
      if (!await _ensureBluetoothPermissions()) return;

      // Clear any stale advertising session left by a previous attempt.
      try {
        await nearby.stopAdvertising();
      } catch (_) {}

      if (mounted) setState(() => status = 'جاري تشغيل استقبال البلوتوث…');
      await nearby.startAdvertising(
        _serviceId,
        strategy,
        onConnectionInitiated: (id, info) {
          nearby.acceptConnection(id, onPayLoadRecieved: _receivePayload);
        },
        onConnectionResult: (id, result) async {
          if (result == Status.CONNECTED) {
            await _sendSnapshot(id);
            if (mounted) setState(() => status = 'اتصل جهاز عامل؛ تتم مزامنة البيانات');
          } else if (mounted) {
            setState(() => status = 'لم يكتمل الاتصال');
          }
        },
        onDisconnected: (id) {
          if (mounted) setState(() => status = 'انقطع اتصال أحد الأجهزة');
        },
      );
      if (mounted) setState(() => status = 'جهاز المسؤول جاهز لاستقبال العاملين');
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        setState(() => status = message.contains('STATUS_ALREADY_ADVERTISING')
            ? 'جهاز المسؤول يعلن بالفعل؛ اضغط إيقاف المزامنة ثم أعد التشغيل.'
            : 'تعذر تشغيل البلوتوث: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _startWorker() async {
    if (!await _ensureBluetoothPermissions()) return;
    setState(() { busy = true; status = 'جاري البحث عن جهاز المسؤول…'; endpoints.clear(); });
    try {
      await nearby.startDiscovery(
        _serviceId,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          if (mounted) setState(() { endpoints[id] = name; status = 'تم العثور على جهاز: $name'; });
        },
        onEndpointLost: (id) {
          if (mounted) setState(() => endpoints.remove(id));
        },
      );
    } catch (e) {
      if (mounted) setState(() => status = 'تعذر البحث: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _connect(String id) async {
    if (!await _ensureBluetoothPermissions()) return;
    setState(() { busy = true; status = 'جاري الاتصال بجهاز المسؤول…'; });
    try {
      await nearby.requestConnection(
        'طلبات-عامل',
        id,
        onConnectionInitiated: (endpointId, info) {
          nearby.acceptConnection(endpointId, onPayLoadRecieved: _receivePayload);
        },
        onConnectionResult: (endpointId, result) async {
          if (result == Status.CONNECTED) {
            await _sendSnapshot(endpointId);
            if (mounted) setState(() => status = 'تم الاتصال؛ تتم مزامنة البيانات');
          } else if (mounted) {
            setState(() => status = 'فشل الاتصال');
          }
        },
        onDisconnected: (endpointId) {
          if (mounted) setState(() => status = 'انقطع الاتصال');
        },
      );
    } catch (e) {
      if (mounted) setState(() => status = 'تعذر الاتصال: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    try {
      await nearby.stopAdvertising();
      await nearby.stopDiscovery();
      await nearby.stopAllEndpoints();
    } catch (_) {}
    if (mounted) setState(() { status = 'تم إيقاف المزامنة'; endpoints.clear(); });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مزامنة البلوتوث')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Icon(Icons.bluetooth, size: 54, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(status, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('اجعل الجهازين قريبين، وفعّل البلوتوث. لا يلزم اتصال بالإنترنت.', textAlign: TextAlign.center),
      ]))),
      const SizedBox(height: 16),
      if (widget.isManager)
        FilledButton.icon(onPressed: busy ? null : _startManager, icon: const Icon(Icons.wifi_tethering), label: const Text('تشغيل جهاز المسؤول')),
      if (!widget.isManager) ...[
        FilledButton.icon(onPressed: busy ? null : _startWorker, icon: const Icon(Icons.search), label: const Text('البحث عن جهاز المسؤول')),
        ...endpoints.entries.map((e) => Card(child: ListTile(title: Text(e.value), leading: const Icon(Icons.phone_android), trailing: const Icon(Icons.bluetooth_connected), onTap: busy ? null : () => _connect(e.key)))),
      ],
      OutlinedButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_circle_outlined), label: const Text('إيقاف المزامنة')),
    ]),
  );
}
