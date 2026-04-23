import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db_service.dart';

class AnalyticsScreen extends StatelessWidget {
  final DbService _dbService = DbService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("АНАЛІТИКА", style: GoogleFonts.orbitron(fontSize: 18)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getLogs(), // Отримуємо всі дані
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          
          final logs = snapshot.data!;
          // Фільтруємо дані для графіка (беремо останні 20 точок)
          final tempPoints = logs.where((e) => e['type'] == 'temp').take(20).toList().reversed.toList();
          final humPoints = logs.where((e) => e['type'] == 'hum').take(20).toList().reversed.toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        // Лінія температури
                        LineChartBarData(
                          spots: tempPoints.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['value'])).toList(),
                          color: Colors.orange,
                          dotData: FlDotData(show: false),
                        ),
                        // Лінія вологості
                        LineChartBarData(
                          spots: humPoints.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['value'])).toList(),
                          color: Colors.blue,
                          dotData: FlDotData(show: false),
                        ),
                      ],
                      // Налаштування сітки та осей
                      titlesData: FlTitlesData(show: true),
                      gridData: FlGridData(show: true),
                    ),
                  ),
                ),
                // Легенда
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendItem("Температура", Colors.orange),
                    SizedBox(width: 20),
                    _legendItem("Вологість", Colors.blue),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, color: color),
      SizedBox(width: 4),
      Text(text)
    ]);
  }
}