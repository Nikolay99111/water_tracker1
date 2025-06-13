import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Moscow'));
  Intl.defaultLocale = 'ru_RU';

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await notificationsPlugin.initialize(initSettings);

  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3E2F2F),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      home: WaterHome(prefs: prefs),
    );
  }
}

class WaterHome extends StatefulWidget {
  final SharedPreferences prefs;
  const WaterHome({Key? key, required this.prefs}) : super(key: key);

  @override
  State<WaterHome> createState() => _WaterHomeState();
}

class _WaterHomeState extends State<WaterHome> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _loadCounter();
  }

  void _loadCounter() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month}-${today.day}';
    final lastKey = widget.prefs.getString('lastDay');
    if (lastKey != key) {
      widget.prefs.setInt('counter', 0);
      widget.prefs.setString('lastDay', key);
      _counter = 0;
    } else {
      _counter = widget.prefs.getInt('counter') ?? 0;
    }
    setState(() {});
  }

  Future<void> _increment() async {
    final now = DateTime.now();
    final key = '${now.year}-${now.month}-${now.day}';
    setState(() => _counter++);
    widget.prefs.setInt('counter', _counter);
    widget.prefs.setString('lastDay', key);
    widget.prefs.setInt('history_$key', _counter);

    if (widget.prefs.getString('lastRemind') != key) {
      for (int i = 1; i <= 5; i++) {
        final scheduleTime = tz.TZDateTime.now(tz.local).add(Duration(hours: 2 * i));
        await notificationsPlugin.zonedSchedule(
          i,
          'Напоминание',
          'Выпей 200\u00A0мл воды',
          scheduleTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'water_channel',
              'Water reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      widget.prefs.setString('lastRemind', key);
    }
  }

  Future<void> _openSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatisticsScreen(prefs: widget.prefs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _counter >= 8
        ? Colors.lightBlueAccent
        : Color.lerp(Colors.redAccent, Colors.lightBlueAccent, _counter / 8)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\uD83D\uDCA7 Water Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _openStats,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _increment,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size(160, 160),
                backgroundColor: color,
              ),
              child: Text('Я выпил $_counter', style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 20),
            const Text('Продолжай в том же духе!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSettings,
        child: const Icon(Icons.notifications_active),
      ),
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  final SharedPreferences prefs;
  const StatisticsScreen({Key? key, required this.prefs}) : super(key: key);

  List<BarChartGroupData> _groups() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = '${day.year}-${day.month}-${day.day}';
      final value = prefs.getInt('history_$key') ?? 0;
      final color = value >= 8
          ? Colors.lightBlueAccent
          : Color.lerp(Colors.redAccent, Colors.lightBlueAccent, value / 8)!;
      return BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: value.toDouble(), color: color, width: 16)],
      );
    });
  }

  List<String> _labels() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final wd = DateFormat.E('ru_RU').format(day);  // \u041F\u043D, \u0412\u0442...
      final d = DateFormat('d MMMM', 'ru_RU').format(day); // 3 \u043C\u0430\u044F
      return '$wd\n$d';
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels();
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BarChart(
          BarChartData(
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 64,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    return Text(labels[idx], textAlign: TextAlign.center);
                  },
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: _groups(),
          ),
        ),
      ),
    );
  }
}
