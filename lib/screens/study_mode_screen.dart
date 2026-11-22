import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/services/study_mode_config.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
export 'package:vesta_app/services/study_mode_config.dart';

/// Study mode settings for a minor.
///
/// While it is on, Vesta Tracker only lets the apps allowed here and the
/// essential system apps (phone, SMS, settings, keyboard) open. The block is
/// applied on the device and also works offline.
class StudyModeScreen extends StatefulWidget {
  final String childId;

  const StudyModeScreen({super.key, required this.childId});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen> {
  static const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  StudyModeConfig? _config;
  bool _saving = false;
  Object? _loadError;
  String _appQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await StudyModeConfig.ref(widget.childId).get();
      if (mounted) {
        setState(() => _config = StudyModeConfig.fromDoc(snapshot.data()));
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _save(StudyModeConfig config, {String? message}) async {
    setState(() {
      _saving = true;
      _config = config;
    });

    try {
      await config.save(widget.childId);
      if (mounted && message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _activate(Duration? duration) {
    final config = _config!;
    return _save(
      duration == null
          ? config.copyWith(active: true, clearEndsAt: true)
          : config.copyWith(
              active: true,
              endsAt: DateTime.now().add(duration),
            ),
      message: tr('Modo estudio activado.'),
    );
  }

  Future<void> _deactivate() {
    return _save(
      _config!.copyWith(active: false, clearEndsAt: true),
      message: tr('Modo estudio desactivado.'),
    );
  }

  Future<void> _addSchedule() async {
    final schedule = await showDialog<StudySchedule>(
      context: context,
      builder: (_) => const _ScheduleDialog(),
    );
    if (schedule == null) return;

    final config = _config!;
    if (config.schedules.length >= 7) return;
    await _save(
      config.copyWith(schedules: [...config.schedules, schedule]),
      message: tr('Horario añadido.'),
    );
  }

  Future<void> _removeSchedule(int index) {
    final schedules = [..._config!.schedules]..removeAt(index);
    return _save(_config!.copyWith(schedules: schedules));
  }

  Future<void> _toggleApp(String packageName, bool allowed) {
    final apps = {..._config!.allowedApps};
    if (allowed) {
      if (apps.length >= 100) return Future.value();
      apps.add(packageName);
    } else {
      apps.remove(packageName);
    }
    return _save(_config!.copyWith(allowedApps: apps.toList()..sort()));
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(
        title: Text(tr('Modo estudio')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('No se pudo cargar el modo estudio. Requiere que todos los tutores autoricen el control de aplicaciones.\n\n{0}', [_loadError]),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VestaTheme.textSecondary),
                ),
              ),
            )
          : config == null
              ? const Center(
                  child: CircularProgressIndicator(color: VestaTheme.rose),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _statusCard(config),
                    const SizedBox(height: 22),
                    _sectionTitle(tr('HORARIOS AUTOMÁTICOS')),
                    const SizedBox(height: 8),
                    ...config.schedules.asMap().entries.map(
                          (entry) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule_rounded),
                              title: Text(entry.value.label),
                              trailing: IconButton(
                                tooltip: tr('Eliminar horario'),
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: _saving
                                    ? null
                                    : () => _removeSchedule(entry.key),
                              ),
                            ),
                          ),
                        ),
                    if (config.schedules.length < 7)
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addSchedule,
                        icon: const Icon(Icons.add_alarm_rounded),
                        label: Text(tr('Añadir horario')),
                      ),
                    const SizedBox(height: 22),
                    _sectionTitle(tr('APPS PERMITIDAS DURANTE EL ESTUDIO')),
                    const SizedBox(height: 4),
                    Text(
                      tr('Teléfono, mensajes, ajustes y teclado siempre están disponibles. Marca las apps que necesita para estudiar.'),
                      style: TextStyle(
                        color: VestaTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _appsList(config),
                  ],
                ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: TextStyle(
          color: VestaTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      );

  Widget _statusCard(StudyModeConfig config) {
    final now = DateTime.now();
    final manualOn = config.active &&
        (config.endsAt == null || now.isBefore(config.endsAt!));
    final scheduledEnd = config.schedules
        .map((s) => s.activeEnd(now))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    final String subtitle;
    if (manualOn) {
      subtitle = config.endsAt == null
          ? tr('Activo hasta que lo desactives.')
          : tr('Activo hasta las {0}.', [_time(config.endsAt!)]);
    } else if (scheduledEnd != null) {
      subtitle = tr('Activo por horario hasta las {0}.', [_time(scheduledEnd)]);
    } else {
      subtitle = tr('Desactivado.');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: manualOn || scheduledEnd != null
            ? const LinearGradient(colors: [Color(0xFF3B5BA5), VestaTheme.rose])
            : null,
        color: manualOn || scheduledEnd != null ? null : VestaTheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Text(
                tr('Modo estudio'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 14),
          if (manualOn)
            FilledButton.icon(
              onPressed: _saving ? null : _deactivate,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: VestaTheme.wine,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(tr('Desactivar ahora')),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  (Duration(minutes: 30), tr('30 min')),
                  (Duration(hours: 1), tr('1 hora')),
                  (Duration(hours: 2), tr('2 horas')),
                ])
                  ActionChip(
                    avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(option.$2),
                    onPressed: _saving ? null : () => _activate(option.$1),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.all_inclusive_rounded, size: 18),
                  label: Text(tr('Sin límite')),
                  onPressed: _saving ? null : () => _activate(null),
                ),
              ],
            ),
          if (scheduledEnd != null && !manualOn) ...[
            const SizedBox(height: 8),
            Text(
              tr('Para terminar antes, elimina o modifica el horario.'),
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _appsList(StudyModeConfig config) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('installed_apps')
          .where('isInstalled', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            tr('No se pudo cargar la lista de aplicaciones.'),
            style: TextStyle(color: VestaTheme.textSecondary),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final query = _appQuery.trim().toLowerCase();
        final apps = snapshot.data!.docs
            .map((doc) => doc.data())
            .where((app) {
              if (query.isEmpty) return true;
              final name = (app['appName'] ?? '').toString().toLowerCase();
              final pkg = (app['packageName'] ?? '').toString().toLowerCase();
              return name.contains(query) || pkg.contains(query);
            })
            .toList()
          ..sort((a, b) {
            final aAllowed = config.allowedApps.contains(a['packageName']);
            final bAllowed = config.allowedApps.contains(b['packageName']);
            if (aAllowed != bAllowed) return aAllowed ? -1 : 1;
            return (a['appName'] ?? '')
                .toString()
                .toLowerCase()
                .compareTo((b['appName'] ?? '').toString().toLowerCase());
          });

        if (snapshot.data!.docs.isEmpty) {
          return Text(
            tr('Todavía no hay aplicaciones sincronizadas desde el dispositivo.'),
            style: TextStyle(color: VestaTheme.textSecondary),
          );
        }

        return Column(
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: tr('Buscar aplicación'),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _appQuery = value),
            ),
            const SizedBox(height: 8),
            ...apps.map((app) {
              final packageName = (app['packageName'] ?? '').toString();
              final allowed = config.allowedApps.contains(packageName);
              final iconBase64 = (app['iconBase64'] ?? '').toString();

              Widget leading = const Icon(Icons.android_rounded);
              if (iconBase64.isNotEmpty) {
                try {
                  leading = Image.memory(
                    base64Decode(iconBase64),
                    width: 34,
                    height: 34,
                    gaplessPlayback: true,
                  );
                } catch (_) {}
              }

              return CheckboxListTile(
                value: allowed,
                onChanged: _saving
                    ? null
                    : (value) => _toggleApp(packageName, value == true),
                secondary: leading,
                title: Text((app['appName'] ?? packageName).toString()),
                subtitle: Text(
                  packageName,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog();

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  final Set<int> _days = {1, 2, 3, 4, 5};
  TimeOfDay _start = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final same = _fmt(_start) == _fmt(_end);
    final overnight =
        _end.hour * 60 + _end.minute < _start.hour * 60 + _start.minute;

    return AlertDialog(
      title: Text(tr('Nuevo horario')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(_StudyModeScreenState._dayLetters[day - 1]),
                  selected: _days.contains(day),
                  onSelected: (selected) => setState(
                    () => selected ? _days.add(day) : _days.remove(day),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text(tr('Desde {0}', [_fmt(_start)])),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text(tr('Hasta {0}', [_fmt(_end)])),
                ),
              ),
            ],
          ),
          if (overnight)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                tr('Termina al día siguiente (útil como “hora de dormir”).'),
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancelar')),
        ),
        FilledButton(
          onPressed: _days.isEmpty || same
              ? null
              : () {
                  final days = _days.toList()..sort();
                  Navigator.pop(
                    context,
                    StudySchedule(
                      days: days,
                      start: _fmt(_start),
                      end: _fmt(_end),
                    ),
                  );
                },
          child: Text(tr('Añadir')),
        ),
      ],
    );
  }
}
