import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для тактильного відгуку (вібрації)
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart'; // Для форматування часу
import 'mqtt_service.dart';
import 'log_screen.dart';
import 'db_service.dart';
import 'export_service.dart';
import 'analytics_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final MqttService mqtt = MqttService();
  final DbService _dbService = DbService();
  String _lastUpdate = "--:--:--";

  @override
  void initState() {
    super.initState();
    mqtt.connect();
    
    // Оновлюємо час при отриманні будь-яких даних з потоків
    mqtt.tempStream.listen((_) => _updateTime());
    mqtt.humStream.listen((_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
  }

  Future<void> _exportData() async {
    final allLogs = await _dbService.getLogs();
    if (allLogs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Журнал порожній. Немає даних для завантаження."))
        );
      }
      return;
    }
    await ExportService.exportLogsToCSV(allLogs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("IoT MONITOR", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 18)),
            _buildConnectionStatus(),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _buildInteractiveCard(
                "TEMPERATURE", mqtt.tempStream, "°C", Colors.orange, 
                LucideIcons.thermometer, mqtt.settings.tempMin, mqtt.settings.tempMax
              ),
              const SizedBox(height: 20),
              _buildInteractiveCard(
                "HUMIDITY", mqtt.humStream, "%", Colors.blue, 
                LucideIcons.droplets, mqtt.settings.humMin, mqtt.settings.humMax
              ),
              const SizedBox(height: 20),
              Text("Останнє оновлення: $_lastUpdate", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          _buildAlarmOverlay(),
        ],
      ),
    );
  }

  // Віджет статусу зв'язку
  Widget _buildConnectionStatus() {
    return StreamBuilder<MqttConnectionState>(
      stream: mqtt.stateStream,
      builder: (context, snap) {
        final state = snap.data ?? MqttConnectionState.disconnected;
        Color color = Colors.grey;
        String label = "Підключення...";

        if (state == MqttConnectionState.connected) {
          color = Colors.green;
          label = "Клієнт активний";
        } else if (state == MqttConnectionState.error) {
          color = Colors.red;
          label = "Помилка зв'язку";
        }

        return Row(
          children: [
            Container(
              width: 8, height: 8, 
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      }
    );
  }

  // Клікабельна картка з переходом до аналітики
  Widget _buildInteractiveCard(String title, Stream<String> stream, String unit, Color color, IconData icon, double min, double max) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        double val = double.tryParse(snap.data ?? '0') ?? 0;
        bool alarm = (val < min || val > max) && snap.hasData;
        
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsScreen())),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(20),
              border: alarm ? Border.all(color: Colors.red, width: 2) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(icon, color: alarm ? Colors.red : color, size: 40),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    Text("${snap.data ?? '--'} $unit", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: alarm ? Colors.red : Colors.black)),
                  ]),
                ]),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Ціль: ${min.round()}-${max.round()}$unit", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(color: Colors.indigo),
          accountName: Text("Роман 41-КІ", style: GoogleFonts.orbitron()),
          accountEmail: const Text("Система активна"),
          currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(LucideIcons.cpu)),
        ),
        ListTile(
          leading: const Icon(LucideIcons.settings),
          title: const Text("Налаштувати ліміти"),
          onTap: () { Navigator.pop(context); _showSettings(); },
        ),
        ListTile(
          leading: const Icon(LucideIcons.history),
          title: const Text("Журнал даних"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LogScreen()));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.lineChart),
          title: const Text("Графіки аналітики"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsScreen()));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.downloadCloud, color: Colors.indigo),
          title: const Text("Експорт звіту (CSV)"),
          onTap: () {
            Navigator.pop(context);
            _exportData();
          },
        ),
      ]),
    );
  }

  Widget _buildAlarmOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAlarmBanner('temp', mqtt.tempStream),
            _buildAlarmBanner('hum', mqtt.humStream),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmBanner(String type, Stream<String> stream) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink(); 
        double val = double.tryParse(snap.data!) ?? 0;
        String? msg = mqtt.settings.checkAlarm(val, type);
        if (msg == null) return const SizedBox.shrink(); 

        return Container(
          margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(builder: (context, setST) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("ЛІМІТИ ТРИВОГ", style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setST(() {
                        mqtt.settings.tempMin = 18; mqtt.settings.tempMax = 26;
                        mqtt.settings.humMin = 40; mqtt.settings.humMax = 60;
                        mqtt.settings.update(18, 26, 40, 60);
                      });
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 16),
                    label: const Text("Скинути"),
                  )
                ],
              ),
              const SizedBox(height: 20),
              _buildRangeSlider(
                "Температура", "°C", LucideIcons.thermometer, Colors.orange,
                mqtt.settings.tempMin, mqtt.settings.tempMax, 0, 100,
                (v) => setST(() { mqtt.settings.tempMin = v.start; mqtt.settings.tempMax = v.end; })
              ),
              const Divider(height: 40),
              _buildRangeSlider(
                "Вологість", "%", LucideIcons.droplets, Colors.blue,
                mqtt.settings.humMin, mqtt.settings.humMax, 0, 100,
                (v) => setST(() { mqtt.settings.humMin = v.start; mqtt.settings.humMax = v.end; })
              ),
            ]
          ),
        );
      }),
    );
  }

  Widget _buildRangeSlider(String label, String unit, IconData icon, Color color, double min, double max, double absMin, double absMax, Function(RangeValues) onCh) {
    return Column(children: [
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text("${min.round()}-${max.round()} $unit", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
      RangeSlider(
        values: RangeValues(min, max),
        min: absMin, max: absMax,
        divisions: absMax.toInt(),
        activeColor: color,
        inactiveColor: color.withValues(alpha: 0.2),
        onChanged: (v) { HapticFeedback.selectionClick(); onCh(v); },
        onChangeEnd: (v) => mqtt.settings.update(mqtt.settings.tempMin, mqtt.settings.tempMax, mqtt.settings.humMin, mqtt.settings.humMax),
      )
    ]);
  }
}