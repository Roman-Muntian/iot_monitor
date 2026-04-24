import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'db_service.dart';
import 'main.dart';

class AnalyticsScreen extends StatelessWidget {
  final DbService _dbService = DbService();

  AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context)?.isDark ?? true;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return DynamicBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "АНАЛІТИКА",
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: textColor,
            ),
          ),
          iconTheme: IconThemeData(
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _dbService.getLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white54 : Colors.indigo,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.barChart2,
                      size: 64,
                      color: subtextColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Дані відсутні",
                      style: TextStyle(
                        fontSize: 18,
                        color: subtextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            final logs = snapshot.data!;

            final tempLogs = logs
                .where((e) => e['type'] == 'temp')
                .take(20)
                .toList()
                .reversed
                .toList();
            final humLogs = logs
                .where((e) => e['type'] == 'hum')
                .take(20)
                .toList()
                .reversed
                .toList();

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

            if (minY == double.infinity) {
              minY = 0;
              maxY = 100;
            } else {
              minY = (minY - 5).clamp(0, double.infinity);
              maxY += 5;
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.only(
                            right: 24,
                            top: 24,
                            bottom: 16,
                            left: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: LineChart(
                            LineChartData(
                              minY: minY,
                              maxY: maxY,
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  fitInsideHorizontally: true,
                                  fitInsideVertically: true,
                                  tooltipPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tooltipRoundedRadius: 12,
                                  getTooltipColor: (touchedSpot) => isDark
                                      ? const Color(0xFF1E293B)
                                          .withValues(alpha: 0.95)
                                      : Colors.white.withValues(alpha: 0.95),
                                  tooltipBorder: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.1),
                                  ),
                                  getTooltipItems: (touchedSpots) {
                                    return touchedSpots.map((spot) {
                                      final isTemp = spot.barIndex == 0;
                                      return LineTooltipItem(
                                        "${spot.y.toStringAsFixed(1)} ${isTemp ? '°C' : '%'}",
                                        TextStyle(
                                          color:
                                              isTemp ? Colors.orange : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: [
                                // Temperature line
                                LineChartBarData(
                                  spots: tempPoints,
                                  isCurved: true,
                                  curveSmoothness: 0.3,
                                  color: Colors.orange,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.orange,
                                        strokeWidth: 2,
                                        strokeColor: isDark
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.withValues(
                                            alpha: isDark ? 0.3 : 0.2),
                                        Colors.orange.withValues(alpha: 0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                // Humidity line
                                LineChartBarData(
                                  spots: humPoints,
                                  isCurved: true,
                                  curveSmoothness: 0.3,
                                  color: Colors.blue,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                        strokeColor: isDark
                                            ? const Color(0xFF0F172A)
                                            : Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withValues(
                                            alpha: isDark ? 0.3 : 0.2),
                                        Colors.blue.withValues(alpha: 0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval:
                                        (tempLogs.length / 5).ceilToDouble(),
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index >= 0 &&
                                          index < tempLogs.length) {
                                        DateTime time = DateTime.parse(
                                            tempLogs[index]['timestamp']);
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: Text(
                                            DateFormat('HH:mm').format(time),
                                            style: TextStyle(
                                              color: subtextColor,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
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
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval:
                                    ((maxY - minY) / 5).ceilToDouble(),
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: gridColor,
                                  strokeWidth: 1,
                                  dashArray: [6, 4],
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Legend
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGlassLegendItem(
                              "Температура (°C)",
                              Colors.orange,
                              isDark,
                            ),
                            const SizedBox(width: 32),
                            _buildGlassLegendItem(
                              "Вологість (%)",
                              Colors.blue,
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlassLegendItem(String text, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
