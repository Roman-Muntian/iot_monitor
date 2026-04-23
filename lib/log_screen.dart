import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'db_service.dart';
import 'export_service.dart';
import 'mqtt_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final DbService _dbService = DbService();
  final MqttService _mqtt = MqttService(); // Для доступу до лімітів
  
  String _selectedType = 'Всі';
  String _searchDate = '';
  bool _isAscending = false;

  // Метод для групування логів за датою
  Map<String, List<Map<String, dynamic>>> _groupLogsByDate(List<Map<String, dynamic>> logs) {
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
    if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now)) {
      return "Сьогодні";
    }
    return DateFormat('d MMMM, yyyy', 'uk_UA').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("ЖУРНАЛ ДАНИХ"),
        actions: [
          IconButton(
            // ВИПРАВЛЕНО: Замінено іконки на стандартні arrowUp та arrowDown
            icon: Icon(_isAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown),
            onPressed: () => setState(() => _isAscending = !_isAscending),
          ),
          IconButton(
            icon: const Icon(LucideIcons.download),
            onPressed: _exportCurrentView,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _dbService.getLogs(type: _selectedType, date: _searchDate),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  var logs = snapshot.data!;
                  if (_isAscending) logs = logs.reversed.toList();
                  
                  if (logs.isEmpty) {
                    return const Center(child: Text("Записів не знайдено"));
                  }

                  final groupedLogs = _groupLogsByDate(logs);
                  final dateKeys = groupedLogs.keys.toList();

                  return ListView.builder(
                    itemCount: dateKeys.length,
                    itemBuilder: (context, index) {
                      String dateKey = dateKeys[index];
                      List<Map<String, dynamic>> dayLogs = groupedLogs[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateHeader(dateKey),
                          // ВИПРАВЛЕНО: Прибрано зайвий .toList() в кінці рядка
                          ...dayLogs.map((log) => _buildLogTile(log)),
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
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip("Всі"),
            const SizedBox(width: 8),
            _filterChip("Температура"),
            const SizedBox(width: 8),
            _filterChip("Вологість"),
            const VerticalDivider(),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _searchDate = DateFormat('yyyy-MM-dd').format(date));
                }
              },
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(_searchDate.isEmpty ? "Дата" : _searchDate),
            ),
            if (_searchDate.isNotEmpty)
              IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () => setState(() => _searchDate = ''),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    bool selected = _selectedType == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _selectedType = label),
      selectedColor: Colors.indigo.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: selected ? Colors.indigo : Colors.black),
    );
  }

  Widget _buildDateHeader(String dateKey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.withValues(alpha: 0.1),
      child: Text(
        _formatHeaderDate(dateKey).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final type = log['type'];
    final value = log['value'];
    final time = DateFormat('HH:mm:ss').format(DateTime.parse(log['timestamp']));
    
    // Перевірка на аномалії
    bool isAnomaly = false;
    if (type == 'temp') {
      isAnomaly = value < _mqtt.settings.tempMin || value > _mqtt.settings.tempMax;
    } else {
      isAnomaly = value < _mqtt.settings.humMin || value > _mqtt.settings.humMax;
    }

    return Dismissible(
      key: Key(log['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      onDismissed: (dir) => _dbService.clearLogs(), // Тут краще додати метод видалення по ID
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isAnomaly ? Colors.red.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isAnomaly ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
        ),
        child: ListTile(
          leading: Icon(
            type == 'temp' ? LucideIcons.thermometer : LucideIcons.droplets,
            color: type == 'temp' ? Colors.orange : Colors.blue,
          ),
          title: Text(
            "$value ${type == 'temp' ? '°C' : '%'}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAnomaly ? Colors.red : Colors.black,
            ),
          ),
          subtitle: Text(type == 'temp' ? "Температура" : "Вологість"),
          trailing: Text(time, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }

  Future<void> _exportCurrentView() async {
    final logs = await _dbService.getLogs(type: _selectedType, date: _searchDate);
    if (logs.isNotEmpty) {
      await ExportService.exportLogsToCSV(logs);
    }
  }
}