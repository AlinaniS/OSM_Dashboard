import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
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
  static const LatLng _currentLocation = LatLng(-15.3875, 28.3228);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS Tracker Dashboard'),
        actions: [
          Icon(Icons.wifi,
              color: Colors.green), // Placeholder for connection status
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          center: _currentLocation,
          zoom: 15.0,
        ),
        children: [
          // OpenStreetMap tiles with cancellable tile provider
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.open_dashboard',
          ),

          // Marker layer
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation,
                width: 80,
                height: 80,
                child: Icon(
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
