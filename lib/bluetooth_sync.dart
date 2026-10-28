import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
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
  final Map<String, String> endpoints = {};
  String status = 'اختر وضع المزامنة ثم اجعل الجهازين قريبين';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    
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
    setState(() { busy = true; status = 'جاري تشغيل استقبال البلوتوث…'; });
    try {
      await nearby.startAdvertising(
        'طلبات-المسؤول',
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
      if (mounted) setState(() => status = 'تعذر تشغيل البلوتوث: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _startWorker() async {
    setState(() { busy = true; status = 'جاري البحث عن جهاز المسؤول…'; endpoints.clear(); });
    try {
      await nearby.askLocationPermission();
      await nearby.startDiscovery(
        'طلبات-عامل',
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
