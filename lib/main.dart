import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'mqtt_service.dart';
import 'log_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
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

  @override
  void initState() {
    super.initState();
    mqtt.connect();
    mqtt.alertStream.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text("IoT MONITOR", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold))),
      drawer: Drawer(
        child: Column(children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            accountName: Text("Роман 41-КІ", style: GoogleFonts.orbitron()),
            accountEmail: const Text("Система активна"),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(LucideIcons.user)),
          ),
          ListTile(
            leading: const Icon(LucideIcons.settings),
            title: const Text("Налаштувати ліміти"),
            onTap: () { Navigator.pop(context); _showSettings(); },
          ),
          // --- ДОДАНИЙ БЛОК ДЛЯ ЖУРНАЛУ ДАНИХ ---
          ListTile(
            leading: const Icon(LucideIcons.history),
            title: const Text("Журнал даних"),
            onTap: () {
              Navigator.pop(context); // Закриваємо бічне меню перед переходом
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const LogScreen())
              );
            },
          ),
          // --------------------------------------
        ]),
      ),
      // --- ВІДНОВЛЕНИЙ БЛОК BODY ---
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildCard("TEMPERATURE", mqtt.tempStream, "°C", Colors.orange, LucideIcons.thermometer, mqtt.settings.tempMin, mqtt.settings.tempMax),
          const SizedBox(height: 20),
          _buildCard("HUMIDITY", mqtt.humStream, "%", Colors.blue, LucideIcons.droplets, mqtt.settings.humMin, mqtt.settings.humMax),
        ]),
      ),
      // -----------------------------
    ); // Відновлено закриваючу дужку Scaffold
  } // Відновлено закриваючу дужку методу build

  Widget _buildCard(String title, Stream<String> stream, String unit, Color color, IconData icon, double min, double max) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        double val = double.tryParse(snap.data ?? '0') ?? 0;
        bool alarm = (val < min || val > max) && snap.hasData;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20),
            border: alarm ? Border.all(color: Colors.red, width: 2) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: alarm ? Colors.red : color, size: 40),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text("${snap.data ?? '--'} $unit", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: alarm ? Colors.red : Colors.black)),
            ]),
          ]),
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setST) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("ЛІМІТИ", style: GoogleFonts.orbitron(fontSize: 18)),
            _slider("Temp Min", mqtt.settings.tempMin, 10, 25, (v) => setST(() => mqtt.settings.update(v, mqtt.settings.tempMax, mqtt.settings.humMin, mqtt.settings.humMax))),
            _slider("Temp Max", mqtt.settings.tempMax, 26, 50, (v) => setST(() => mqtt.settings.update(mqtt.settings.tempMin, v, mqtt.settings.humMin, mqtt.settings.humMax))),
            const Divider(),
            _slider("Hum Min", mqtt.settings.humMin, 0, 45, (v) => setST(() => mqtt.settings.update(mqtt.settings.tempMin, mqtt.settings.tempMax, v, mqtt.settings.humMax))),
            _slider("Hum Max", mqtt.settings.humMax, 46, 100, (v) => setST(() => mqtt.settings.update(mqtt.settings.tempMin, mqtt.settings.tempMax, mqtt.settings.humMin, v))),
            const SizedBox(height: 20),
          ]),
        );
      }),
    );
  }

  Widget _slider(String label, double val, double min, double max, Function(double) fn) {
    return Column(children: [Text("$label: ${val.round()}"), Slider(value: val.clamp(min, max), min: min, max: max, onChanged: (v) { fn(v); setState(() {}); })]);
  }
}