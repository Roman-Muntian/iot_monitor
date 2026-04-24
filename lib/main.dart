import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'mqtt_service.dart';
import 'log_screen.dart';
import 'db_service.dart';
import 'export_service.dart';
import 'analytics_screen.dart';
import 'settings_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SettingsService _settings = SettingsService();
  bool _isDark = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.load();
    setState(() {
      _isDark = _settings.isDark;
      _isLoading = false;
    });
  }

  void toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      _settings.setDarkMode(_isDark);
    });
  }

  bool get isDark => _isDark;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.indigo.shade400,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: _isDark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: 2,
          ),
          iconTheme: IconThemeData(
            color: _isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: _isDark ? Colors.white : const Color(0xFF0F172A)),
          bodyMedium: TextStyle(color: _isDark ? Colors.white70 : const Color(0xFF334155)),
        ),
      ),
      home: const Dashboard(),
    );
  }
}

// ============================================================================
// DYNAMIC ANIMATED BACKGROUND WITH NEBULOUS BLOBS
// ============================================================================
class DynamicBackground extends StatefulWidget {
  final bool isDark;
  final Widget child;

  const DynamicBackground({
    super.key,
    required this.isDark,
    required this.child,
  });

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (index) {
      return AnimationController(
        duration: Duration(seconds: 8 + _random.nextInt(6)),
        vsync: this,
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: Offset(_random.nextDouble() * 0.3, _random.nextDouble() * 0.3),
        end: Offset(_random.nextDouble() * 0.3 + 0.1, _random.nextDouble() * 0.3 + 0.1),
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Blob colors for dark mode (vibrant, higher opacity)
    final darkBlobs = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFFEA580C), // Deep Orange
      const Color(0xFF0891B2), // Cyan
      const Color(0xFF7C3AED), // Violet
    ];

    // Blob colors for light mode (softer, lower opacity)
    final lightBlobs = [
      const Color(0xFF818CF8), // Light Indigo
      const Color(0xFFFB923C), // Light Orange
      const Color(0xFF22D3EE), // Light Cyan
      const Color(0xFFA78BFA), // Light Violet
    ];

    final colors = widget.isDark ? darkBlobs : lightBlobs;
    final blobOpacity = widget.isDark ? 0.35 : 0.25;

    return Stack(
      children: [
        // Base background color
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                  : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
            ),
          ),
        ),
        // Animated blobs
        ...List.generate(4, (index) {
          final positions = [
            Offset(-size.width * 0.2, -size.height * 0.1),
            Offset(size.width * 0.5, -size.height * 0.2),
            Offset(-size.width * 0.1, size.height * 0.5),
            Offset(size.width * 0.4, size.height * 0.6),
          ];
          final sizes = [
            size.width * 0.8,
            size.width * 0.7,
            size.width * 0.9,
            size.width * 0.6,
          ];

          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Positioned(
                left: positions[index].dx + (_animations[index].value.dx * size.width * 0.3),
                top: positions[index].dy + (_animations[index].value.dy * size.height * 0.3),
                child: Container(
                  width: sizes[index],
                  height: sizes[index],
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors[index].withValues(alpha: blobOpacity),
                        colors[index].withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Heavy backdrop blur for nebulous effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
        // Child content
        widget.child,
      ],
    );
  }
}

// ============================================================================
// GLASSMORPHISM CARD WIDGET
// ============================================================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? accentColor;
  final bool isAlarm;
  final bool isDark;
  final double borderRadius;
  final double blurSigma;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.accentColor,
    this.isAlarm = false,
    required this.isDark,
    this.borderRadius = 24,
    this.blurSigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = isAlarm
        ? Colors.red.withValues(alpha: 0.4)
        : (accentColor?.withValues(alpha: isDark ? 0.15 : 0.1) ?? Colors.transparent);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isDark ? 20 : 15,
            spreadRadius: isDark ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
              border: Border.all(
                color: isAlarm
                    ? Colors.red.withValues(alpha: 0.6)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05)),
                width: isAlarm ? 2 : 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DASHBOARD
// ============================================================================
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
          SnackBar(
            content: const Text("Журнал порожній. Немає даних для завантаження."),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    await ExportService.exportLogsToCSV(allLogs);
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "IOT MONITOR",
                style: GoogleFonts.orbitron(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 3,
                  color: textColor,
                ),
              ),
              _buildConnectionStatus(isDark),
            ],
          ),
          actions: [
            // Theme toggle button
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                MyApp.of(context)?.toggleTheme();
              },
              icon: Icon(
                isDark ? LucideIcons.sun : LucideIcons.moon,
                color: isDark ? Colors.amber : const Color(0xFF334155),
              ),
            ),
          ],
        ),
        drawer: _buildGlassDrawer(isDark, textColor, subtextColor),
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInteractiveCard(
                      "TEMPERATURE",
                      mqtt.tempStream,
                      "°C",
                      Colors.orange,
                      LucideIcons.thermometer,
                      mqtt.settings.tempMin,
                      mqtt.settings.tempMax,
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildInteractiveCard(
                      "HUMIDITY",
                      mqtt.humStream,
                      "%",
                      Colors.blue,
                      LucideIcons.droplets,
                      mqtt.settings.humMin,
                      mqtt.settings.humMax,
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Останнє оновлення: $_lastUpdate",
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildAlarmOverlay(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    return StreamBuilder<MqttConnectionState>(
      stream: mqtt.stateStream,
      builder: (context, snap) {
        final state = snap.data ?? MqttConnectionState.disconnected;
        Color color = Colors.grey;
        String label = "Підключення...";

        if (state == MqttConnectionState.connected) {
          color = const Color(0xFF10B981);
          label = "Клієнт активний";
        } else if (state == MqttConnectionState.error) {
          color = Colors.red;
          label = "Помилка зв'язку";
        }

        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveCard(
    String title,
    Stream<String> stream,
    String unit,
    Color color,
    IconData icon,
    double min,
    double max,
    bool isDark,
  ) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        double val = double.tryParse(snap.data ?? '0') ?? 0;
        bool alarm = (val < min || val > max) && snap.hasData;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnalyticsScreen()),
            );
          },
          child: GlassCard(
            isDark: isDark,
            isAlarm: alarm,
            accentColor: color,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (alarm ? Colors.red : color).withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: alarm ? Colors.red : color,
                        size: 32,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            letterSpacing: 2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: val),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedVal, child) {
                            return Text(
                              "${snap.hasData ? animatedVal.toStringAsFixed(1) : '--'} $unit",
                              style: GoogleFonts.orbitron(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: alarm
                                    ? Colors.red
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                letterSpacing: 2,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ціль: ${min.round()}-${max.round()}$unit",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassDrawer(bool isDark, Color textColor, Color subtextColor) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: DynamicBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GlassCard(
                          isDark: isDark,
                          padding: const EdgeInsets.all(12),
                          borderRadius: 20,
                          child: Icon(
                            LucideIcons.cpu,
                            color: isDark ? Colors.white : const Color(0xFF4F46E5),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Роман 41-КІ",
                                style: GoogleFonts.orbitron(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "IoT Система Активна",
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        "ГОЛОВНЕ МЕНЮ",
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          color: subtextColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    _buildGlassMenuItem(
                      title: "Налаштування лімітів",
                      icon: LucideIcons.sliders,
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showSettings();
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildGlassMenuItem(
                      title: "Журнал подій",
                      icon: LucideIcons.clipboardList,
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LogScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildGlassMenuItem(
                      title: "Аналітика",
                      icon: LucideIcons.barChart2,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AnalyticsScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        "ЕКСПОРТ",
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          color: subtextColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    _buildGlassMenuItem(
                      title: "Завантажити CSV",
                      icon: LucideIcons.downloadCloud,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _exportData();
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.radioTower,
                      size: 14,
                      color: subtextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "IoT Monitor Pro v1.0",
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      borderRadius: 16,
      blurSigma: 8,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmOverlay(bool isDark) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAlarmBanner('temp', mqtt.tempStream, isDark),
            _buildAlarmBanner('hum', mqtt.humStream, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmBanner(String type, Stream<String> stream, bool isDark) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        double val = double.tryParse(snap.data!) ?? 0;
        String? msg = mqtt.settings.checkAlarm(val, type);
        if (msg == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        msg,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSettings() {
    final isDark = MyApp.of(context)?.isDark ?? true;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 16,
            ),
            child: StatefulBuilder(
              builder: (context, setST) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "НАЛАШТУВАННЯ",
                          style: GoogleFonts.orbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                            letterSpacing: 2,
                          ),
                        ),
                        GlassCard(
                          isDark: isDark,
                          padding: const EdgeInsets.all(8),
                          borderRadius: 12,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setST(() {
                                mqtt.settings.update(18, 26, 40, 60);
                                mqtt.settings.tempMin = 18;
                                mqtt.settings.tempMax = 26;
                                mqtt.settings.humMin = 40;
                                mqtt.settings.humMax = 60;
                              });
                            },
                            child: Icon(
                              LucideIcons.rotateCcw,
                              size: 18,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ModernRangeSlider(
                      label: "Температура",
                      unit: "°C",
                      icon: LucideIcons.thermometer,
                      color: Colors.orange,
                      min: mqtt.settings.tempMin,
                      max: mqtt.settings.tempMax,
                      isDark: isDark,
                      onChanged: (v) => setST(() {
                        mqtt.settings.tempMin = v.start;
                        mqtt.settings.tempMax = v.end;
                      }),
                      onEnd: (v) => mqtt.settings.update(
                        v.start,
                        v.end,
                        mqtt.settings.humMin,
                        mqtt.settings.humMax,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ModernRangeSlider(
                      label: "Вологість",
                      unit: "%",
                      icon: LucideIcons.droplets,
                      color: Colors.blue,
                      min: mqtt.settings.humMin,
                      max: mqtt.settings.humMax,
                      isDark: isDark,
                      onChanged: (v) => setST(() {
                        mqtt.settings.humMin = v.start;
                        mqtt.settings.humMax = v.end;
                      }),
                      onEnd: (v) => mqtt.settings.update(
                        mqtt.settings.tempMin,
                        mqtt.settings.tempMax,
                        v.start,
                        v.end,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN RANGE SLIDER (GLASSMORPHISM STYLE)
// ============================================================================
class ModernRangeSlider extends StatelessWidget {
  final String label, unit;
  final IconData icon;
  final Color color;
  final double min, max;
  final bool isDark;
  final Function(RangeValues) onChanged, onEnd;

  const ModernRangeSlider({
    super.key,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.min,
    required this.max,
    required this.isDark,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                "${min.round()}-${max.round()} $unit",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: isDark ? 0.2 : 0.15),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 10,
              elevation: 4,
            ),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: RangeValues(min, max),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            onChangeEnd: onEnd,
          ),
        ),
      ],
    );
  }
}
