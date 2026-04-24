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
          // Центруємо вміст екрана
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Стискаємо колонку до розміру карток
                children: [
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
                ],
              ),
            ),
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

  // Клікабельна картка з переходом до аналітики (ОНОВЛЕНО З АНІМАЦІЄЮ ЧИСЕЛ)
  Widget _buildInteractiveCard(String title, Stream<String> stream, String unit, Color color, IconData icon, double min, double max) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        // Парсимо значення з MQTT
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
              boxShadow: [
                BoxShadow(
                  color: alarm 
                    ? Colors.red.withValues(alpha: 0.2) 
                    : color.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Icon(icon, color: alarm ? Colors.red : color, size: 40),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    
                    // --- ПЛАВНА АНІМАЦІЯ ЦИФР ---
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: val), // Вказуємо кінцеве значення
                      duration: const Duration(milliseconds: 800), // Тривалість плавного переходу (0.8 сек)
                      curve: Curves.easeOutCubic, // Тип анімації: швидко стартує, плавно гальмує
                      builder: (context, animatedVal, child) {
                        return Text(
                          "${snap.hasData ? animatedVal.toStringAsFixed(1) : '--'} $unit", 
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.bold, 
                            color: alarm ? Colors.red : Colors.black
                          )
                        );
                      },
                    ),
                    // ----------------------------
                    
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
      backgroundColor: const Color(0xFFF8FAFC), // Дуже світлий сіро-синій фон
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          // Преміальна шапка з абстракцією
          SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                // Основний градієнт
                Container(
                  height: 230,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF3730A3)], // Від темного сланцю до глибокого індиго
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
                // Абстрактні кола для техно-стилю
                Positioned(
                  right: -50, top: -50,
                  child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))),
                ),
                Positioned(
                  right: 40, bottom: -40,
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))),
                ),
                // Вміст шапки
                Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 30, bottom: 25, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Аватар з індикатором онлайн
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                            ),
                            child: const Icon(LucideIcons.cpu, color: Colors.white, size: 36),
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981), // Смарагдовий
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF3730A3), width: 2),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text("Роман 41-КІ", style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text("IoT Система Активна", style: TextStyle(color: Colors.indigo.shade200, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          // Пункти меню
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              children: [
                const SizedBox(height: 10),
                Text("ГОЛОВНЕ МЕНЮ", style: GoogleFonts.orbitron(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                _buildPremiumDrawerItem(
                  title: "Налаштування лімітів",
                  icon: LucideIcons.sliders,
                  color: const Color(0xFFF59E0B), // Бурштиновий
                  onTap: () { Navigator.pop(context); _showSettings(); }
                ),
                const SizedBox(height: 8),
                _buildPremiumDrawerItem(
                  title: "Журнал подій",
                  icon: LucideIcons.clipboardList,
                  color: const Color(0xFF3B82F6), // Синій
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LogScreen()));
                  }
                ),
                const SizedBox(height: 8),
                _buildPremiumDrawerItem(
                  title: "Аналітика",
                  icon: LucideIcons.barChart2,
                  color: const Color(0xFF8B5CF6), // Фіолетовий
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyticsScreen()));
                  }
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.black12, height: 1),
                ),
                
                Text("ЕКСПОРТ", style: GoogleFonts.orbitron(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                _buildPremiumDrawerItem(
                  title: "Завантажити CSV",
                  icon: LucideIcons.downloadCloud,
                  color: const Color(0xFF10B981), // Смарагдовий
                  onTap: () {
                    Navigator.pop(context);
                    _exportData();
                  }
                ),
              ],
            ),
          ),
          
          // Підвал (Footer)
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.radioTower, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text("IoT Monitor Pro v1.0", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Дизайн преміальної кнопки меню
  Widget _buildPremiumDrawerItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        highlightColor: color.withValues(alpha: 0.05),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              // Іконка в білому боксі з кольоровою тінню
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))
                  ]
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              // Текст
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF334155)))),
              // Стрілочка
              Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
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
      backgroundColor: Colors.transparent, // Для заокруглених кутів
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 24, right: 24, top: 12,
        ),
        child: StatefulBuilder(builder: (context, setST) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Смужка-індикатор зверху
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("НАЛАШТУВАННЯ", style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  IconButton.filledTonal(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setST(() {
                        mqtt.settings.update(18, 26, 40, 60);
                        mqtt.settings.tempMin = 18; mqtt.settings.tempMax = 26;
                        mqtt.settings.humMin = 40; mqtt.settings.humMax = 60;
                      });
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  )
                ],
              ),
              const SizedBox(height: 30),
              ModernRangeSlider(
                label: "Температура",
                unit: "°C",
                icon: LucideIcons.thermometer,
                color: Colors.orange,
                min: mqtt.settings.tempMin,
                max: mqtt.settings.tempMax,
                onChanged: (v) => setST(() { 
                  mqtt.settings.tempMin = v.start; 
                  mqtt.settings.tempMax = v.end; 
                }),
                onEnd: (v) => mqtt.settings.update(v.start, v.end, mqtt.settings.humMin, mqtt.settings.humMax),
              ),
              const SizedBox(height: 25),
              ModernRangeSlider(
                label: "Вологість",
                unit: "%",
                icon: LucideIcons.droplets,
                color: Colors.blue,
                min: mqtt.settings.humMin,
                max: mqtt.settings.humMax,
                onChanged: (v) => setST(() { 
                  mqtt.settings.humMin = v.start; 
                  mqtt.settings.humMax = v.end; 
                }),
                onEnd: (v) => mqtt.settings.update(mqtt.settings.tempMin, mqtt.settings.tempMax, v.start, v.end),
              ),
              const SizedBox(height: 20),
            ],
          );
        }),
      ),
    );
  }
}

// Новий віджет для повзунків
class ModernRangeSlider extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final Color color;
  final double min, max;
  final Function(RangeValues) onChanged, onEnd;

  const ModernRangeSlider({
    super.key, required this.label, required this.unit, required this.icon,
    required this.color, required this.min, required this.max, 
    required this.onChanged, required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text("${min.round()}-${max.round()} $unit", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        RangeSlider(
          values: RangeValues(min, max),
          min: 0, max: 100,
          divisions: 100,
          activeColor: color,
          inactiveColor: color.withOpacity(0.1),
          onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); },
          onChangeEnd: onEnd,
        ),
      ],
    );
  }
}