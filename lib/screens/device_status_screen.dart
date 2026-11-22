import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
class DeviceStatusScreen extends StatefulWidget {
  final String childId;

  const DeviceStatusScreen({
    super.key,
    required this.childId,
  });

  @override
  State<DeviceStatusScreen> createState() => _DeviceStatusScreenState();
}

class _DeviceStatusScreenState extends State<DeviceStatusScreen> {
  static const Color _wine = Color(0xFF792D43);
  static const Color _rose = Color(0xFFC15B68);
  static Color get _ivory => VestaTheme.textPrimary;
  static const Color _dark = Color(0xFF211B20);
  static const Color _muted = Color(0xFF8D7D82);
  static const Duration _offlineThreshold = Duration(minutes: 12);

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  DateTime? _parseLastUpdate(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    return null;
  }

  String _lastUpdate(dynamic value) {
    final date = _parseLastUpdate(value);
    if (date == null) return tr('Sin información');

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} · $hour:$minute';
  }

  // Created once. It used to be created in build() and the 30 s timer
  // reopened the subscription, showing the loading indicator every time.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> statusStream =
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('device_status')
          .doc('current')
          .snapshots();

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        gradient: VestaTheme.screenGradient,
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: statusStream,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return _messageState(
              Icons.cloud_off_rounded,
              tr('No se pudo cargar la información del dispositivo.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _rose),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _messageState(
              Icons.phone_android_rounded,
              tr('Esperando información del dispositivo Tracker...'),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final battery = data['batteryLevel'];
          final charging = data['isCharging'] == true;
          final level = battery is num ? battery.toInt() : null;

          final lastUpdate = _parseLastUpdate(data['updatedAt']);
          final offline = lastUpdate != null &&
              _now.difference(lastUpdate) > _offlineThreshold;

          // The server reports disconnection (device_offline alert).

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 25),
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 18),
              _communicationCard(offline, lastUpdate),
              const SizedBox(height: 14),
              _batteryCard(level, charging),
              const SizedBox(height: 23),
              Text(
                tr('INFORMACIÓN DEL EQUIPO'),
                style: TextStyle(
                  color: _ivory,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              _infoCard(
                Icons.phone_android_rounded,
                tr('Fabricante'),
                data['manufacturer']?.toString() ?? tr('Sin información'),
              ),
              _infoCard(
                Icons.devices_rounded,
                tr('Modelo'),
                data['model']?.toString() ?? tr('Sin información'),
              ),
              _infoCard(
                Icons.branding_watermark_rounded,
                tr('Marca'),
                data['brand']?.toString() ?? tr('Sin información'),
              ),
              _infoCard(
                Icons.android_rounded,
                tr('Versión de Android'),
                data['androidVersion'] == null
                    ? tr('Sin información')
                    : tr('{0} (SDK {1})', [data['androidVersion'], data['androidSdk'] ?? '?']),
              ),
              _infoCard(
                Icons.wifi_rounded,
                tr('Conectividad'),
                data['connectivity']?.toString() ?? tr('Sin información'),
              ),
              _infoCard(
                Icons.battery_charging_full_rounded,
                tr('Estado de batería'),
                data['batteryState']?.toString() ?? tr('Sin información'),
              ),
              _infoCard(
                Icons.access_time_rounded,
                tr('Última comunicación'),
                _lastUpdate(data['updatedAt']),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: 16,
                      color: _ivory.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr('La información se actualiza mientras Vesta Tracker permanece activo.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ivory.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _messageState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _rose,
              size: 48,
            ),
            const SizedBox(height: 17),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ivory.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_wine, _rose],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _rose.withValues(alpha: 0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: const Icon(
            Icons.phone_android_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Estado del dispositivo'),
                style: TextStyle(
                  color: _ivory,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                tr('Supervisión de Vesta Tracker'),
                style: TextStyle(
                  color: VestaTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _communicationCard(bool offline, DateTime? lastUpdate) {
    final color = offline
        ? _rose
        : const Color(0xFF559B79);

    final title = offline
        ? tr('SIN COMUNICACIÓN')
        : tr('DISPOSITIVO CONECTADO');

    final subtitle = offline
        ? tr('No se reciben actualizaciones desde hace más de 12 minutos.')
        : tr('Se están recibiendo actualizaciones del dispositivo.');

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              offline
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (lastUpdate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr('Último contacto: {0}', [_lastUpdate(lastUpdate)]),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryCard(int? level, bool charging) {
    final color = level == null
        ? _muted
        : level <= 10
            ? _rose
            : level <= 20
                ? const Color(0xFFE39A52)
                : const Color(0xFF559B79);

    final progress = level == null
        ? 0.0
        : (level.clamp(0, 100) / 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: _rose.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                charging
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_full_rounded,
                color: color,
                size: 31,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  tr('Batería'),
                  style: TextStyle(
                    color: _ivory,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                level == null ? '--' : '$level%',
                style: TextStyle(
                  color: color,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                charging
                    ? Icons.power_rounded
                    : Icons.power_off_rounded,
                color: _ivory.withValues(alpha: 0.65),
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                charging ? tr('Conectado al cargador') : tr('No está cargando'),
                style: TextStyle(
                  color: _ivory.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: _ivory,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0xFFE9DCE0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _wine, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
