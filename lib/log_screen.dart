import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Новий імпорт
import 'db_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final DbService _dbService = DbService();
  String _selectedType = 'Температура'; // За замовчуванням
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    String? dateString = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("АНАЛІТИКА", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getLogs(type: _selectedType, date: dateString),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          
          return Column(
            children: [
              // Панель фільтрів
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Температура', label: Text('Темп.'), icon: Icon(LucideIcons.thermometer, size: 16)),
                          ButtonSegment(value: 'Вологість', label: Text('Вол.'), icon: Icon(LucideIcons.droplets, size: 16)),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (val) => setState(() => _selectedType = val.first),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(LucideIcons.calendar, color: _selectedDate != null ? Colors.indigo : Colors.grey),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),

              // ГРАФІК
              if (logs.isNotEmpty)
                Container(
                  height: 250,
                  padding: const EdgeInsets.only(right: 25, left: 10, top: 20, bottom: 10),
                  child: LineChart(_buildChartData(logs)),
                ),

              const SizedBox(height: 10),
              
              // СПИСОК
              Expanded(
                child: logs.isEmpty 
                  ? const Center(child: Text("Немає даних"))
                  : ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, i) => _buildLogTile(logs[i]),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  LineChartData _buildChartData(List<Map<String, dynamic>> logs) {
    // Реверсуємо, щоб старі записи були зліва, нові - справа
    final reversedLogs = logs.reversed.toList();
    final isTemp = _selectedType == 'Температура';
    
    return LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: const FlTitlesData(show: false), // Ховаємо цифри по осях для чистоти
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: reversedLogs.asMap().entries.map((e) {
            return FlSpot(e.key.toDouble(), e.value['value'].toDouble());
          }).toList(),
          isCurved: true,
          color: isTemp ? Colors.orange : Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true, 
            color: (isTemp ? Colors.orange : Colors.blue).withOpacity(0.1)
          ),
        ),
      ],
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final date = DateTime.parse(log['timestamp']);
    final isTemp = log['type'] == 'temp';
    return ListTile(
      leading: Icon(isTemp ? LucideIcons.thermometer : LucideIcons.droplets, color: isTemp ? Colors.orange : Colors.blue),
      title: Text(DateFormat('HH:mm:ss').format(date)),
      trailing: Text("${log['value']} ${isTemp ? '°C' : '%'}", style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}