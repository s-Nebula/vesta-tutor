import 'tr.dart';

/// Title and body of an alert in the app language.
///
/// Alerts are stored with the text in the language of the phone that wrote
/// them (the minor's phone, or Spanish for server alerts). They also carry an
/// `eventKey` and, for some events, the values needed to rebuild the text,
/// so they are shown here in the guardian's language. Unknown events, or
/// events missing a value, keep the stored text.
///
/// Keep in sync with the API's `src/services/push_texts.js`.
class AlertText {
  const AlertText(this.title, this.body);

  final String title;
  final String body;

  static AlertText of(Map<String, dynamic> data, {String? lang}) {
    final en = (lang ?? appLanguage) == 'en';
    final built = _build(data, en);
    if (built != null) return built;
    return AlertText(
      _str(data['title']) ?? tr('Alerta'),
      _str(data['subtitle']) ?? tr('Incidente registrado'),
    );
  }

  static AlertText? _build(Map<String, dynamic> a, bool en) {
    AlertText t(String esTitle, String esBody, String enTitle, String enBody) =>
        en ? AlertText(enTitle, enBody) : AlertText(esTitle, esBody);

    final subtitle = a['subtitle']?.toString() ?? '';

    switch (a['eventKey']?.toString()) {
      case 'battery_low':
        final level = _firstNumber(subtitle);
        if (level == null) return null;
        return t('Batería baja', 'La batería del dispositivo está al $level%.',
            'Low battery', 'The device battery is at $level%.');
      case 'battery_critical':
        final level = _firstNumber(subtitle);
        if (level == null) return null;
        return t(
            'Batería crítica',
            'La batería está al $level%. Conecte el dispositivo a un cargador.',
            'Critical battery',
            'The battery is at $level%. Plug the device into a charger.');
      case 'zone_enter':
        final zone = _str(a['zoneName']);
        if (zone == null) return null;
        return t('Llegó a $zone', 'El dispositivo entró en la zona segura "$zone".',
            'Arrived at $zone', 'The device entered the safe zone "$zone".');
      case 'zone_exit':
        final zone = _str(a['zoneName']);
        if (zone == null) return null;
        return t('Salió de $zone', 'El dispositivo salió de la zona segura "$zone".',
            'Left $zone', 'The device left the safe zone "$zone".');
      case 'speed':
        final kmh = _firstNumber(subtitle);
        if (kmh == null) return null;
        return t('Exceso de velocidad', 'Velocidad detectada: $kmh km/h',
            'Speeding', 'Speed detected: $kmh km/h');
      case 'location_permission_revoked':
        return t(
            'Permiso de ubicación retirado',
            'Se retiró el permiso de ubicación de Vesta Tracker en el dispositivo.',
            'Location permission removed',
            "Vesta Tracker's location permission was removed on the device.");
      case 'location_disabled':
        return t(
            'Ubicación desactivada',
            'Se desactivó la ubicación del dispositivo. El mapa dejará de actualizarse.',
            'Location turned off',
            'Location was turned off on the device. The map will stop updating.');
      case 'location_enabled':
        return t('Ubicación reactivada', 'El dispositivo vuelve a compartir su ubicación.',
            'Location back on', 'The device is sharing its location again.');
      case 'offline_period':
        final minutes = _int(a['offlineMinutes']);
        if (minutes == null) return null;
        return t(
            'Dispositivo sin conexión',
            'El dispositivo estuvo sin internet durante ${formatMinutes(minutes, 'es')}. Ya volvió a conectarse.',
            'Device offline',
            'The device had no internet for ${formatMinutes(minutes, 'en')}. It is back online.');
      case 'device_offline':
        final minutes = _int(a['offlineMinutes']);
        if (minutes == null) return null;
        return t(
            'Dispositivo sin conexión',
            'Vesta Tracker no envía datos desde hace ${formatMinutes(minutes, 'es')}. '
                'Puede estar apagado, sin batería, sin internet o con la app detenida.',
            'Device offline',
            'Vesta Tracker has not sent data for ${formatMinutes(minutes, 'en')}. '
                'It may be switched off, out of battery, without internet or with the app stopped.');
      case 'blocked_app':
        final app = _afterColon(subtitle);
        if (app == null) return null;
        return t('Aplicación bloqueada', 'Intentó abrir: $app', 'App blocked', 'Tried to open: $app');
      case 'blocked_domain':
        final domain = _str(a['domain']) ?? _afterColon(subtitle);
        if (domain == null) return null;
        return t('Acceso bloqueado', 'Intentó acceder a: $domain',
            'Access blocked', 'Tried to access: $domain');
      case 'app_limit_reached':
        final match = RegExp(r"(?:de hoy en|today's time on) (.+)$").firstMatch(subtitle);
        final app = match == null ? null : _str(match.group(1));
        if (app == null) return null;
        return t('Tiempo diario agotado', 'Usó todo el tiempo de hoy en $app',
            'Daily time used up', "Used all of today's time on $app");
      case 'study_mode_block':
        final app = _afterColon(subtitle);
        if (app == null) return null;
        return t('Intento de uso en modo estudio', 'Intentó abrir: $app',
            'Attempted use in study mode', 'Tried to open: $app');
      case 'vpn_revoked':
        return t(
            'Filtro web desactivado',
            'Se desconectó la protección DNS de Vesta en el dispositivo.',
            'Web filter turned off',
            'Vesta DNS protection was disconnected on the device.');
      case 'accessibility_disabled':
        return t(
            'Bloqueo de apps desactivado',
            'Se desactivó el servicio de accesibilidad de Vesta en el dispositivo.',
            'App blocking turned off',
            "Vesta's accessibility service was turned off on the device.");
      case 'sos':
        final located = a['lat'] is num && a['lng'] is num;
        return located
            ? t('SOS: necesita ayuda', 'Pulsó el botón de emergencia. Toca para ver su ubicación.',
                'SOS: needs help', 'Pressed the emergency button. Tap to see their location.')
            : t('SOS: necesita ayuda', 'Pulsó el botón de emergencia en su teléfono.',
                'SOS: needs help', 'Pressed the emergency button on their phone.');
    }
    return null;
  }

  /// "25 minutos" / "2.5 horas" (Spanish) or "25 minutes" / "2.5 hours".
  static String formatMinutes(int minutes, String lang) {
    final en = lang == 'en';
    if (minutes < 120) {
      if (en) return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    }
    final hours = (minutes / 60).toStringAsFixed(1).replaceAll('.0', '');
    return en ? '$hours hours' : '$hours horas';
  }

  static String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(Object? value) => value is num ? value.round() : null;

  static String? _firstNumber(String text) =>
      RegExp(r'\d+(?:[.,]\d+)?').firstMatch(text)?.group(0)?.replaceAll(',', '.');

  static String? _afterColon(String text) {
    final index = text.lastIndexOf(': ');
    return index < 0 ? null : _str(text.substring(index + 2));
  }
}
