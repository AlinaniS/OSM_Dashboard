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
        useMaterial3: false, // Android 5 compatibility
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
  String _speechStatus = '';

  // MQTT client
  late MqttServerClient client;
  bool _isConnected = false;
  String _lastUpdateTime = 'No updates yet';

  // Map style
  String _currentMapStyle = 'Standard';
  final Map<String, String> _mapStyles = {
    'Standard': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Satellite':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'Terrain': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
  };

  /// Search location via Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1");

    try {
      final response =
          await http.get(url, headers: {'User-Agent': 'gps-tracker-app'});

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]["lat"]);
          final lon = double.parse(data[0]["lon"]);
          setState(() {
            _currentLocation = LatLng(lat, lon);
          });
          _mapController.move(_currentLocation, 15.0);
          _showSnackBar("Location found: ${data[0]["display_name"]}");
        } else {
          _showSnackBar("No results found for '$query'");
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
    bool available = await _speech.initialize(
      onStatus: (status) {
        setState(() {
          _speechStatus = status;
        });
        _logger.info('Speech status: $status');
      },
      onError: (error) {
        _logger.severe('Speech error: $error');
        _showSnackBar("Speech recognition error");
        setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _searchController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            _searchLocation(result.recognizedWords);
            _stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      );
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
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
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
      _showSnackBar("Connected to GPS tracker");
      client.subscribe('esp32/gps', MqttQos.atMostOnce);
    };
    client.onDisconnected = () {
      setState(() => _isConnected = false);
      _logger.info('Disconnected from MQTT broker');
      _showSnackBar("Disconnected from GPS tracker");
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
          _lastUpdateTime = _formatTime(DateTime.now());
        });

        // Auto-center map on new location
        _mapController.move(_currentLocation, _mapController.camera.zoom);
      } catch (e) {
        _logger.severe('Invalid GPS format: $e');
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  void _changeMapStyle(String style) {
    setState(() {
      _currentMapStyle = style;
    });
    Navigator.pop(context);
  }

  void _centerOnCurrentLocation() {
    _mapController.move(_currentLocation, 15.0);
  }

  @override
  void dispose() {
    // Clean up resources
    _searchController.dispose();
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          children: [
            const Icon(Icons.pin_drop, size: 24),
            const SizedBox(width: 8),
            const Text(
              'GPS Tracker',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'Connected' : 'Offline',
                      style: TextStyle(
                        color: _isConnected
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.navigation, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'GPS Tracker Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last update: $_lastUpdateTime',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map Style'),
              subtitle: Text(_currentMapStyle),
            ),
            ..._mapStyles.keys.map((style) => ListTile(
                  leading: Radio<String>(
                    value: style,
                    groupValue: _currentMapStyle,
                    onChanged: (value) => _changeMapStyle(value!),
                  ),
                  title: Text(style),
                  onTap: () => _changeMapStyle(style),
                )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Center on Location'),
              onTap: () {
                _centerOnCurrentLocation();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reconnect MQTT'),
              onTap: () {
                _connectToMqtt();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'GPS Tracker Dashboard',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.pin_drop),
                  children: [
                    const Text(
                        'Real-time GPS tracking dashboard using MQTT protocol.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyles[_currentMapStyle]!,
                userAgentPackageName: 'com.example.gps_tracker',
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

          // Search bar overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Search location...",
                          border: InputBorder.none,
                        ),
                        onSubmitted: _searchLocation,
                      ),
                    ),
                    // Voice search button with better visual feedback
                    Container(
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.blue,
                        ),
                        onPressed:
                            _isListening ? _stopListening : _startListening,
                        tooltip:
                            _isListening ? 'Stop listening' : 'Voice search',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Listening indicator
          if (_isListening)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: Colors.red.shade50,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Listening...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating action button for centering
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _centerOnCurrentLocation,
              tooltip: 'Center on location',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
