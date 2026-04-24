import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'db_service.dart';
import 'export_service.dart';
import 'mqtt_service.dart';
import 'main.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final DbService _dbService = DbService();
  final MqttService _mqtt = MqttService();

  String _selectedType = 'Всі';
  String _searchDate = '';
  bool _isAscending = false;

  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(
      List<Map<String, dynamic>> logs) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var log in logs) {
      DateTime date = DateTime.parse(log['timestamp']);
      String dayKey = DateFormat('yyyy-MM-dd').format(date);
      if (grouped[dayKey] == null) grouped[dayKey] = [];
      grouped[dayKey]!.add(log);
    }
    return grouped;
  }

  String _formatHeaderDate(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    DateTime now = DateTime.now();
    if (DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(now)) {
      return "Сьогодні";
    }
    return DateFormat('d MMMM, yyyy', 'uk_UA').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context)?.isDark ?? true;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return DynamicBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "ЖУРНАЛ ДАНИХ",
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
              color: textColor,
            ),
          ),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _isAscending = !_isAscending);
              },
            ),
            IconButton(
              icon: Icon(
                LucideIcons.download,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                _exportCurrentView();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildGlassFilterBar(isDark, textColor, subtextColor),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: isDark ? Colors.white : Colors.indigo,
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _dbService.getLogs(
                      type: _selectedType, date: _searchDate),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.white54 : Colors.indigo,
                        ),
                      );
                    }

                    var logs = snapshot.data!;
                    if (_isAscending) logs = logs.reversed.toList();

                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.inbox,
                              size: 64,
                              color: subtextColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Записів не знайдено",
                              style: TextStyle(
                                fontSize: 16,
                                color: subtextColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final groupedLogs = _groupLogsByDate(logs);
                    final dateKeys = groupedLogs.keys.toList();

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: dateKeys.length,
                      itemBuilder: (context, index) {
                        String dateKey = dateKeys[index];
                        List<Map<String, dynamic>> dayLogs =
                            groupedLogs[dateKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGlassDateHeader(
                                dateKey, isDark, subtextColor),
                            ...dayLogs.map((log) =>
                                _buildGlassLogTile(log, isDark, textColor)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFilterBar(
      bool isDark, Color textColor, Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGlassFilterChip("Всі", isDark, textColor),
                  const SizedBox(width: 8),
                  _buildGlassFilterChip("Температура", isDark, textColor),
                  const SizedBox(width: 8),
                  _buildGlassFilterChip("Вологість", isDark, textColor),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const SizedBox(width: 12),
                  _buildGlassDateButton(isDark, textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassFilterChip(String label, bool isDark, Color textColor) {
    bool selected = _selectedType == label;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedType = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                  : const Color(0xFF4F46E5).withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDateButton(bool isDark, Color textColor) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            HapticFeedback.selectionClick();
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark
                        ? const ColorScheme.dark(
                            primary: Color(0xFF4F46E5),
                            surface: Color(0xFF1E293B),
                          )
                        : const ColorScheme.light(
                            primary: Color(0xFF4F46E5),
                          ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(
                  () => _searchDate = DateFormat('yyyy-MM-dd').format(date));
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _searchDate.isNotEmpty
                  ? (isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFF10B981).withValues(alpha: 0.15))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: 16,
                  color: _searchDate.isNotEmpty
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Text(
                  _searchDate.isEmpty ? "Дата" : _searchDate,
                  style: TextStyle(
                    color: _searchDate.isNotEmpty
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_searchDate.isNotEmpty)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _searchDate = '');
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                LucideIcons.x,
                size: 16,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassDateHeader(
      String dateKey, bool isDark, Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        _formatHeaderDate(dateKey).toUpperCase(),
        style: GoogleFonts.orbitron(
          fontWeight: FontWeight.bold,
          color: subtextColor,
          fontSize: 11,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildGlassLogTile(
      Map<String, dynamic> log, bool isDark, Color textColor) {
    final type = log['type'];
    final value = log['value'];
    final time =
        DateFormat('HH:mm:ss').format(DateTime.parse(log['timestamp']));

    bool isAnomaly = false;
    if (type == 'temp') {
      isAnomaly =
          value < _mqtt.settings.tempMin || value > _mqtt.settings.tempMax;
    } else {
      isAnomaly =
          value < _mqtt.settings.humMin || value > _mqtt.settings.humMax;
    }

    final accentColor = type == 'temp' ? Colors.orange : Colors.blue;

    return Dismissible(
      key: Key(log['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (dir) => _dbService.clearLogs(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isAnomaly
                    ? Colors.red.withValues(alpha: isDark ? 0.15 : 0.1)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAnomaly
                      ? Colors.red.withValues(alpha: 0.4)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.05)),
                ),
                boxShadow: isAnomaly
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isAnomaly ? Colors.red : accentColor)
                        .withValues(alpha: isDark ? 0.2 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type == 'temp'
                        ? LucideIcons.thermometer
                        : LucideIcons.droplets,
                    color: isAnomaly ? Colors.red : accentColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  "$value ${type == 'temp' ? '°C' : '%'}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isAnomaly
                        ? Colors.red
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    letterSpacing: 0.5,
                  ),
                ),
                subtitle: Text(
                  type == 'temp' ? "Температура" : "Вологість",
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                trailing: Text(
                  time,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCurrentView() async {
    final logs =
        await _dbService.getLogs(type: _selectedType, date: _searchDate);
    if (logs.isNotEmpty) {
      await ExportService.exportLogsToCSV(logs);
    }
  }
}
