import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'db_service.dart';

class AnalyticsScreen extends StatelessWidget {
  final DbService _dbService = DbService();

  AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Світлий фон як на головному екрані
      appBar: AppBar(
        title: Text("АНАЛІТИКА", style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.barChart2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Дані відсутні", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          
          final logs = snapshot.data!;
          
          // Фільтруємо та беремо останні 20 точок (для плавності графіка)
          final tempLogs = logs.where((e) => e['type'] == 'temp').take(20).toList().reversed.toList();
          final humLogs = logs.where((e) => e['type'] == 'hum').take(20).toList().reversed.toList();

          // Генеруємо точки (FlSpot) та визначаємо межі для осі Y
          double minY = double.infinity;
          double maxY = double.negativeInfinity;

          List<FlSpot> tempPoints = [];
          for (int i = 0; i < tempLogs.length; i++) {
            double val = tempLogs[i]['value'];
            tempPoints.add(FlSpot(i.toDouble(), val));
            if (val < minY) minY = val;
            if (val > maxY) maxY = val;
          }

          List<FlSpot> humPoints = [];
          for (int i = 0; i < humLogs.length; i++) {
            double val = humLogs[i]['value'];
            humPoints.add(FlSpot(i.toDouble(), val));
            if (val < minY) minY = val;
            if (val > maxY) maxY = val;
          }

          // Додаємо відступи (padding) для осі Y, щоб графік не прилягав до країв
          if (minY == double.infinity) {
            minY = 0; maxY = 100;
          } else {
            minY = (minY - 5).clamp(0, double.infinity); // Не опускаємось нижче 0
            maxY += 5;
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final isTemp = spot.barIndex == 0;
                                return LineTooltipItem(
                                  "${spot.y.toStringAsFixed(1)} ${isTemp ? '°C' : '%'}",
                                  TextStyle(
                                    color: isTemp ? Colors.orange : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          // Лінія температури
                          LineChartBarData(
                            spots: tempPoints,
                            isCurved: true, // Згладжування
                            color: Colors.orange,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [Colors.orange.withValues(alpha: 0.3), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Лінія вологості
                          LineChartBarData(
                            spots: humPoints,
                            isCurved: true, // Згладжування
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [Colors.blue.withValues(alpha: 0.3), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (tempLogs.length / 5).ceilToDouble(), // Показуємо ~5 міток
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < tempLogs.length) {
                                  // Форматування осі X (Час)
                                  DateTime time = DateTime.parse(tempLogs[index]['timestamp']);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('HH:mm').format(time),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false, // Прибираємо вертикальні лінії для чистоти
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.2), // Світло-сіра сітка
                            strokeWidth: 1,
                            dashArray: [5, 5], // Пунктирна лінія
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Легенда
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendItem("Температура (°C)", Colors.orange),
                    const SizedBox(width: 20),
                    _legendItem("Вологість (%)", Colors.blue),
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
    return Row(
      children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))
      ],
    );
  }
}