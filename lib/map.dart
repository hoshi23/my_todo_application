import 'package:flutter/material.dart';

import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

///////////////////////////////
void main() => runApp(MyApp());

///////////////////////////////
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: ThemeData(), home: MyHomePage());
  }
}

///////////////////////////////
class MyHomePage extends StatefulWidget {
  List<Widget> cards = [];

  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;
  Future<LocationData>? _locationData;

  @override
  void initState() {
    super.initState();

    Location location = new Location();

    location.serviceEnabled().then((value) async {
      _serviceEnabled = value;
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      setState(() {});
      _locationData = location.getLocation();

      // location.onLocationChanged.listen((LocationData currentLocation) async {
      //   setState(() {
      //     _locationData = currentLocation;
      //   });
      // });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Map")),
      body: Center(
        child: FutureBuilder(
          future: _locationData,
          builder: (
              BuildContext context,
              AsyncSnapshot<LocationData> snapshot,
              ) {
            if (snapshot.hasData) {
              var loc = snapshot.data;
              return FlutterMap(
                options: MapOptions(
                    center: (loc != null)
                        ? LatLng(loc.latitude!, loc.longitude!)
                        : LatLng(0, 0),
                    zoom: 18.0),
                layers: [
                  TileLayerOptions(
                    urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                    attributionBuilder: (_) =>
                    const Text("© OpenStreetMap contributors"),
                  ),
                  MarkerLayerOptions(markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: (loc != null)
                          ? LatLng(loc.latitude!, loc.longitude!)
                          : LatLng(0, 0),
                      builder: (ctx) => const Icon(Icons.location_pin),
                    )
                  ]),
                ],
              );
            }
            return const Text("地図をロード中");
          },
        ),
      ),
    );
  }
}