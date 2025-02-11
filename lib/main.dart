import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    runApp(const MyApp());
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<String> _feedLogs = [];
  List<String> _waterLogs = [];
  String _foodStatus = "Checking...";
  String _waterStatus = "Checking...";

  void _updateCommand(String commandPath, bool command) {
    _dbRef.child(commandPath).set(command ? 'true' : 'false');
  }

  void _logEvent(String logPath, String action) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[\.\#\$\[\]]'), '_');
    _dbRef.child('$logPath/$timestamp').set({'action': action, 'time': DateTime.now().toIso8601String()});
  }

  void _listenToLogs(String logPath, Function(List<String>) updateState) {
    _dbRef.child(logPath).onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        List<String> logEntries = [];
        data.forEach((key, value) {
          if (value is Map && value.containsKey('action') && value.containsKey('time')) {
            String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(value['time']));
            logEntries.add('$formattedTime - ${value['action']}');
          }
        });
        logEntries.sort((a, b) => b.compareTo(a));
        updateState(logEntries);
      } else {
        updateState(['No logs available']);
      }
    }, onError: (error) {
      updateState(['Error loading logs: $error']);
    });
  }

  @override
  void initState() {
    super.initState();
    _listenToLogs('feedLogs', (logs) => setState(() => _feedLogs = logs));
    _listenToLogs('waterLogs', (logs) => setState(() => _waterLogs = logs));
    _dbRef.child('foodStatus').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        _foodStatus = data != null ? data.toString() : "Checking..."; // Ensure safe handling of data
      });
    });
    _dbRef.child('waterStatus').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        _waterStatus = data != null ? data.toString() : "Checking..."; // Ensure safe handling of data
      });
    });
  }

 Widget _buildButton(String label, Color color, IconData icon, VoidCallback onTapDown, VoidCallback onTapUp) {
  return GestureDetector(
    onTapDown: (_) => onTapDown(),
    onTapUp: (_) => onTapUp(),
    onTapCancel: () => onTapUp(),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,  // Change size
        height: 160,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 5), // Modify shadow
          ],
          border: Border.all(color: Colors.white, width: 3), // Add border
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 50), // Change icon size
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), // Adjust font
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


 Widget _buildLogSection(String title, List<String> logs, IconData icon, Color color) {
  return Expanded(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
          decoration: BoxDecoration(
            color: color.withOpacity(0.9), // Darker color
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2), // Add border
            ),
            child: logs.isEmpty
                ? const Center(child: Text("No logs available", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(
                          logs[index],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
  title: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.blueAccent,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 6, spreadRadius: 2),
      ],
    ),
    child: const Text(
      '🐾 Smart Pet Feeder & Water Dispenser',
      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  ),
  centerTitle: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
),

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage("assets/pet.jpg"), fit: BoxFit.cover),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildButton(
                    'Feed',
                    Colors.blueAccent,
                    Icons.pets,
                    () {
                      _updateCommand('feedCommand', true);
                      _logEvent('feedLogs', 'Feed pressed');
                    },
                    () {
                      _updateCommand('feedCommand', false);
                      _logEvent('feedLogs', 'Feed released');
                    },
                  ),
                  _buildButton(
                    'Water',
                    Colors.green,
                    Icons.local_drink,
                    () {
                      _updateCommand('waterCommand', true);
                      _logEvent('waterLogs', 'Water pressed');
                    },
                    () {
                      _updateCommand('waterCommand', false);
                      _logEvent('waterLogs', 'Water released');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    Column(
      children: [
        const Text("Food Level", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 235, 14, 206))),
        Text(
          _foodStatus,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _foodStatus == "Low Food Alert" ? Colors.red : Colors.green,
            shadows: [Shadow(color: Colors.black45, blurRadius: 5)], // Add shadow
          ),
        ),
      ],
    ),
    Column(
      children: [
        const Text("Water Level", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(221, 98, 24, 237))),
        Text(
          _waterStatus,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _waterStatus == "Low Water Alert" ? Colors.red : Colors.green,
            shadows: [Shadow(color: Colors.black45, blurRadius: 5)], // Add shadow
          ),
        ),
      ],
    ),
  ],
),

              const SizedBox(height: 30),
              Expanded(
                child: Row(
                  children: [
                    _buildLogSection('📜 Feeding History', _feedLogs, Icons.pets, Colors.blueAccent),
                    const SizedBox(width: 16),
                    _buildLogSection('💧 Watering History', _waterLogs, Icons.local_drink, Colors.green),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error initializing Firebase: $error')),
      ),
    );
  }
}