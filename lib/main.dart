import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

// Initialize logger
final _logger = Logger('GpsTracker');

void main() {
  // Set up logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const GpsTrackerApp());
}

class GpsTrackerApp extends StatelessWidget {
  const GpsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GpsHomePage(),
    );
  }
}

class GpsHomePage extends StatefulWidget {
  const GpsHomePage({super.key});

  @override
  State<GpsHomePage> createState() => _GpsHomePageState();
}

class _GpsHomePageState extends State<GpsHomePage> {
  // Default location: Lusaka, Zambia
  LatLng _currentLocation = const LatLng(-15.3875, 28.3228);

  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // MQTT client
  late MqttServerClient client;
  bool _isConnected = false;

  /// Search location via Nominatim API
  Future<void> _searchLocation(String query) async {
    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1");

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'gps-tracker-app' // required by Nominatim
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]["lat"]);
          final lon = double.parse(data[0]["lon"]);
          setState(() {
            _currentLocation = LatLng(lat, lon);
          });
          _mapController.move(_currentLocation, 15.0);
        } else {
          _showSnackBar("No results found");
        }
      } else {
        _showSnackBar("Error fetching location");
      }
    } catch (e) {
      _logger.severe('Error searching location: $e');
      _showSnackBar("Error searching location");
    }
  }

  /// Handle voice search
  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() {
          _searchController.text = result.recognizedWords;
        });
        if (result.finalResult) {
          _searchLocation(result.recognizedWords);
        }
      });
    } else {
      _showSnackBar("Speech recognition not available");
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _connectToMqtt();
  }

  Future<void> _connectToMqtt() async {
    // Replace with your MQTT broker (local or cloud)
    client = MqttServerClient('broker.hivemq.com',
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onConnected = () {
      setState(() => _isConnected = true);
      _logger.info('Connected to MQTT broker');
      client.subscribe('esp32/gps', MqttQos.atMostOnce);
    };
    client.onDisconnected = () {
      setState(() => _isConnected = false);
      _logger.info('Disconnected from MQTT broker');
    };

    try {
      await client.connect();
    } catch (e) {
      _logger.severe('Connection failed: $e');
      client.disconnect();
    }

    // Listen for GPS updates
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMess = messages[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      _logger.info('Received: $payload');

      try {
        // Assume payload is JSON like {"lat": -15.39, "lon": 28.32}
        final data = jsonDecode(payload);
        final lat = data['lat'] as double;
        final lon = data['lon'] as double;

        setState(() {
          _currentLocation = LatLng(lat, lon);
        });
      } catch (e) {
        _logger.severe('Invalid GPS format: $e');
      }
    });
  }

  @override
  void dispose() {
    // Clean up MQTT client resources
    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _logger.info('Disconnecting MQTT client on dispose');
      client.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Search input
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: "Search location...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: _searchLocation,
              ),
            ),
            // Voice search button
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              onPressed: _isListening ? _stopListening : _startListening,
            ),
            // Connection status
            Icon(
              Icons.wifi,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            // Menu button
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.open_dashboard',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
