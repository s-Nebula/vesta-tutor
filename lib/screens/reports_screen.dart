import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';
import 'package:vesta_app/widgets/weekly_summary_card.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:vesta_app/l10n/tr.dart';
class ReportsScreen extends StatefulWidget {
  final String childId;
  final String tutorId;

  const ReportsScreen({
    super.key,
    required this.childId,
    required this.tutorId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _weekly = true;
  bool _exporting = false;

  static Color get _background => VestaTheme.background;
  static Color get _card => VestaTheme.surface;
  static const Color _accent = VestaTheme.rose;
  static Color get _muted => VestaTheme.textSecondary;

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _duration(int milliseconds) {
    final minutes = milliseconds ~/ 60000;
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) return '${remaining} min';
    return tr('{0} h {1} min', [hours, remaining]);
  }

  DateTime? _dateFromReport(Map<String, dynamic> data) {
    final value = data['date'];
    if (value is String) return DateTime.tryParse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _dayLabel(DateTime? date) {
    if (date == null) return '--';
    final days = [tr('Lun'), tr('Mar'), tr('Mié'), tr('Jue'), tr('Vie'), tr('Sáb'), tr('Dom')];
    return days[date.weekday - 1];
  }

  Map<String, Map<String, dynamic>> _aggregateApps(
    List<Map<String, dynamic>> reports,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final report in reports) {
      final apps = report['apps'];
      if (apps is! List) continue;

      for (final item in apps) {
        if (item is! Map) continue;

        final packageName = item['packageName']?.toString() ?? '';
        if (packageName.isEmpty) continue;

        final app = result.putIfAbsent(
            packageName,
            () => {
                  'packageName': packageName,
                  'appName': item['appName']?.toString() ?? packageName,
                  'foregroundTimeMs': 0,
                  'launchCount': 0,
                });

        app['foregroundTimeMs'] = _number(app['foregroundTimeMs']) +
            _number(item['foregroundTimeMs']);
        app['launchCount'] =
            _number(app['launchCount']) + _number(item['launchCount']);
      }
    }

    return result;
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VestaTheme.surfaceLight, VestaTheme.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VestaTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33211B20),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VestaTheme.wine, VestaTheme.rose],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: TextStyle(
              color: VestaTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: VestaTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 21,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: VestaTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  Widget _usageChart(List<Map<String, dynamic>> reports) {
    final chartReports =
        reports.length > 7 ? reports.sublist(reports.length - 7) : reports;

    if (chartReports.isEmpty) {
      return const SizedBox.shrink();
    }

    final values = chartReports
        .map((r) => _number(r['totalScreenTimeMs']) / 3600000)
        .toList();

    final maxValue = values.fold<double>(
      1,
      (previous, value) => value > previous ? value : previous,
    );

    return Card(
      color: _card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 18, 12),
        child: SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              maxY: maxValue * 1.25,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} h',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toStringAsFixed(0)}h',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= chartReports.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _dayLabel(_dateFromReport(chartReports[index])),
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(chartReports.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: values[index],
                      width: 17,
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appRanking(
    List<Map<String, dynamic>> apps,
    int totalAppUsageMs,
  ) {
    if (apps.isEmpty) {
      return Card(
        color: _card,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            tr('Todavía no hay datos de aplicaciones.'),
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }

    return Card(
      color: _card,
      child: Column(
        children: List.generate(apps.length > 15 ? 15 : apps.length, (index) {
          final app = apps[index];
          final duration = _number(app['foregroundTimeMs']);
          final opens = _number(app['launchCount']);
          final percentage =
              totalAppUsageMs > 0 ? (duration / totalAppUsageMs * 100) : 0.0;

          return Column(
            children: [
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: VestaTheme.wine,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  app['appName']?.toString() ?? tr('Aplicación'),
                  style: TextStyle(
                    color: VestaTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  tr('{0} · {1} aperturas', [_duration(duration), opens]),
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                trailing: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: VestaTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LinearProgressIndicator(
                  value: (percentage / 100).clamp(0.0, 1.0),
                  backgroundColor: VestaTheme.surfaceLight,
                  color: _accent,
                  minHeight: 5,
                ),
              ),
              if (index != apps.length - 1)
                Divider(height: 1, color: VestaTheme.border),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _exportPdf({
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> apps,
    required int totalScreenTime,
    required int totalAppUsage,
    required int totalOpens,
  }) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final document = pw.Document();
      final now = DateTime.now();
      final period =
          _weekly ? tr('Resumen de los últimos 7 días') : tr('Resumen diario');

      pw.Widget cell(String value, {bool header = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );
      }

      final appRows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            cell(tr('Aplicación'), header: true),
            cell(tr('Tiempo'), header: true),
            cell(tr('Aperturas'), header: true),
            cell(tr('% uso'), header: true),
          ],
        ),
      ];

      for (final app in apps.take(30)) {
        final duration = _number(app['foregroundTimeMs']);
        final percentage =
            totalAppUsage > 0 ? duration / totalAppUsage * 100 : 0.0;
        appRows.add(
          pw.TableRow(children: [
            cell(app['appName']?.toString() ?? tr('Aplicación')),
            cell(_duration(duration)),
            cell('${_number(app['launchCount'])}'),
            cell('${percentage.toStringAsFixed(1)}%'),
          ]),
        );
      }

      final dailyRows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            cell(tr('Fecha'), header: true),
            cell(tr('Pantalla activa'), header: true),
            cell(tr('Uso de apps'), header: true),
            cell(tr('Aperturas'), header: true),
          ],
        ),
      ];

      for (final report in reports) {
        final date = _dateFromReport(report);
        dailyRows.add(
          pw.TableRow(children: [
            cell(date == null ? '--' : DateFormat('dd/MM/yyyy').format(date)),
            cell(_duration(_number(report['totalScreenTimeMs']))),
            cell(_duration(_number(report['totalAppUsageMs']))),
            cell('${_number(report['totalAppOpens'])}'),
          ]),
        );
      }

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              tr('VESTA - INFORME DE ACTIVIDAD'),
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(period),
            pw.Text(tr('Generado: {0}', [DateFormat('dd/MM/yyyy HH:mm').format(now)])),
            pw.SizedBox(height: 18),
            pw.Text(
              tr('RESUMEN'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Bullet(
                text: tr('Tiempo de pantalla: {0}', [_duration(totalScreenTime)])),
            pw.Bullet(
                text:
                    tr('Uso acumulado de aplicaciones: {0}', [_duration(totalAppUsage)])),
            pw.Bullet(text: tr('Aperturas registradas: {0}', [totalOpens])),
            pw.SizedBox(height: 18),
            pw.Text(
              tr('ACTIVIDAD DIARIA'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: dailyRows,
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              tr('APLICACIONES MÁS UTILIZADAS'),
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: appRows,
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              tr('Nota: el tiempo de uso de aplicaciones y el tiempo de pantalla son métricas distintas y no necesariamente coinciden.'),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => document.save(),
        name: 'vesta_informe_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo generar el PDF: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildReport(List<Map<String, dynamic>> allReports) {
    final selectedReports = _weekly
        ? (allReports.length > 7
            ? allReports.sublist(allReports.length - 7)
            : allReports)
        : allReports.isEmpty
            ? <Map<String, dynamic>>[]
            : [allReports.last];

    final totalScreenTime = selectedReports.fold<int>(
      0,
      (sum, report) => sum + _number(report['totalScreenTimeMs']),
    );
    final totalAppUsage = selectedReports.fold<int>(
      0,
      (sum, report) => sum + _number(report['totalAppUsageMs']),
    );
    final totalOpens = selectedReports.fold<int>(
      0,
      (sum, report) => sum + _number(report['totalAppOpens']),
    );

    final appMap = _aggregateApps(selectedReports);
    final apps = appMap.values.toList()
      ..sort((a, b) => _number(b['foregroundTimeMs'])
          .compareTo(_number(a['foregroundTimeMs'])));

    final mostUsed = apps.isEmpty ? null : apps.first;
    final peakReport = selectedReports.isEmpty
        ? null
        : selectedReports.reduce((a, b) =>
            _number(a['totalScreenTimeMs']) >= _number(b['totalScreenTimeMs'])
                ? a
                : b);

    final ordered = [...allReports]..sort((a, b) =>
        (_dateFromReport(a) ?? DateTime(2000))
            .compareTo(_dateFromReport(b) ?? DateTime(2000)));

    String trend = tr('Sin datos suficientes');
    if (ordered.length >= 2) {
      final previous =
          _number(ordered[ordered.length - 2]['totalScreenTimeMs']);
      final latest = _number(ordered.last['totalScreenTimeMs']);
      if (previous == 0) {
        trend = latest > 0 ? tr('Aumento') : tr('Sin cambio');
      } else {
        final change = ((latest - previous) / previous * 100);
        trend = '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
      }
    }

    final latestReport = allReports.isEmpty ? null : allReports.last;
    final permissionRequired =
        latestReport?['collectionStatus'] == 'permission_required' &&
            latestReport?['permissionGranted'] != true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeeklySummaryCard(childId: widget.childId),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Actividad del dispositivo'),
                style: TextStyle(
                  color: VestaTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: tr('Exportar PDF'),
              onPressed: selectedReports.isEmpty || _exporting
                  ? null
                  : () => _exportPdf(
                        reports: selectedReports,
                        apps: apps,
                        totalScreenTime: totalScreenTime,
                        totalAppUsage: totalAppUsage,
                        totalOpens: totalOpens,
                      ),
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf, color: _accent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: Text(tr('Últimos 7 días')),
              selected: _weekly,
              onSelected: (_) => setState(() => _weekly = true),
              selectedColor: VestaTheme.wine,
            ),
            ChoiceChip(
              label: Text(tr('Último día')),
              selected: !_weekly,
              onSelected: (_) => setState(() => _weekly = false),
              selectedColor: VestaTheme.wine,
            ),
          ],
        ),
        if (permissionRequired)
          Card(
            color: VestaTheme.surfaceLight,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('El dispositivo necesita habilitar el acceso a los datos de uso para recopilar estadísticas. Activa “Acceso a datos de uso” en los ajustes de Android del dispositivo hijo.'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (allReports.isEmpty)
          Card(
            color: _card,
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                tr('Todavía no hay estadísticas. Los datos aparecerán cuando Vesta Tracker tenga habilitado el acceso a datos de uso y complete su primera recopilación.'),
                style: TextStyle(color: _muted),
              ),
            ),
          ),
        if (selectedReports.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricCard(
                tr('Tiempo de pantalla'),
                _duration(totalScreenTime),
                Icons.screen_lock_portrait,
              ),
              _metricCard(
                tr('Uso de aplicaciones'),
                _duration(totalAppUsage),
                Icons.apps,
              ),
              _metricCard(
                tr('Aperturas de apps'),
                '$totalOpens',
                Icons.touch_app,
              ),
              _metricCard(
                tr('Aplicaciones registradas'),
                '${apps.length}',
                Icons.grid_view,
              ),
            ],
          ),
          _sectionTitle(tr('Actividad diaria')),
          _usageChart(allReports),
          _sectionTitle(tr('Análisis del período')),
          Card(
            color: _card,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(
                    tr('Aplicación más utilizada'),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  subtitle: Text(
                    mostUsed?['appName']?.toString() ?? tr('Sin datos'),
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Text(
                    mostUsed == null
                        ? '--'
                        : _duration(_number(mostUsed['foregroundTimeMs'])),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Divider(color: VestaTheme.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: _accent),
                  title: Text(
                    tr('Día de mayor actividad'),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  subtitle: Text(
                    peakReport == null || _dateFromReport(peakReport) == null
                        ? tr('Sin datos')
                        : DateFormat('dd/MM/yyyy').format(
                            _dateFromReport(peakReport)!,
                          ),
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Text(
                    peakReport == null
                        ? '--'
                        : _duration(_number(peakReport['totalScreenTimeMs'])),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Divider(color: VestaTheme.border, height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.trending_up, color: Colors.lightBlue),
                  title: Text(
                    tr('Variación frente al día anterior'),
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  trailing: Text(
                    trend,
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _sectionTitle(tr('Ranking de aplicaciones')),
          _appRanking(apps, totalAppUsage),
          const SizedBox(height: 8),
          Text(
            tr('El tiempo de pantalla y la suma del tiempo en aplicaciones son métricas distintas. Pueden diferir por actividades del sistema, ventanas múltiples y el método de medición de Android.'),
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('children')
              .doc(widget.childId)
              .collection('usage_reports')
              .orderBy('date', descending: true)
              .limit(30)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  tr('Error cargando estadísticas: {0}', [snapshot.error]),
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _accent),
              );
            }

            final reports = (snapshot.data?.docs ?? [])
                .map((doc) => doc.data())
                .toList()
              ..sort((a, b) => (_dateFromReport(a) ?? DateTime(2000))
                  .compareTo(_dateFromReport(b) ?? DateTime(2000)));

            return _buildReport(reports);
          },
        ),
      ),
    );
  }
}
