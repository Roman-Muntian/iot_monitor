import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final DbService _dbService = DbService();
  String _selectedType = 'Всі';
  DateTime? _selectedDate;

  void _loadData() {
    setState(() {}); 
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
  }

  Future<void> _confirmClearLogs() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Очищення журналу"),
        content: const Text("Ви впевнені, що хочете видалити всі записи? Цю дію неможливо скасувати."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Скасувати")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Видалити", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );

    if (confirm == true) {
      await _dbService.clearLogs();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Журнал успішно очищено"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? dateString = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("ЖУРНАЛ ДАНИХ", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            onPressed: _confirmClearLogs,
            tooltip: "Очистити журнал",
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: ['Всі', 'Температура', 'Вологість'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                ),
                const SizedBox(width: 10),
                // ВИПРАВЛЕНО ТУТ: Замінено ActionChip на InputChip
                InputChip(
                  label: Text(_selectedDate == null ? "Обрати дату" : DateFormat('dd.MM.yyyy').format(_selectedDate!)),
                  avatar: const Icon(LucideIcons.calendar, size: 16),
                  onSelected: (bool selected) => _pickDate(),
                  onDeleted: _selectedDate != null ? _clearDate : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _dbService.getLogs(type: _selectedType, date: dateString),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Немає записів за вказаними фільтрами", style: TextStyle(color: Colors.grey)));
                }

                final logs = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isTemp = log['type'] == 'temp';
                    final date = DateTime.parse(log['timestamp']);
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTemp ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                          child: Icon(isTemp ? LucideIcons.thermometer : LucideIcons.droplets, 
                                     color: isTemp ? Colors.orange : Colors.blue),
                        ),
                        title: Text(
                          isTemp ? "Температура" : "Вологість",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(DateFormat('dd.MM.yyyy HH:mm:ss').format(date)),
                        trailing: Text(
                          "${log['value']} ${isTemp ? '°C' : '%'}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}