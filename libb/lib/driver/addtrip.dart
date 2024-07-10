import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fleetmanagement/admin/widget.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart'; // Ensure to import the correct package for LatLng
import 'package:firebase_auth/firebase_auth.dart';

class TripPage extends StatefulWidget {
  const TripPage({Key? key}) : super(key: key);

  @override
  _TripPageState createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  bool isTripStarted = false;
  bool isAtStartLocation = false;
  bool isAtEndLocation = false;
  List<Map<String, dynamic>> routes = [];
  Map<String, dynamic>? selectedRoute;
  Position? currentPosition;
  String? tripId;
  late String userEmail;

  @override
  void initState() {
    super.initState();
    getUserEmail();
  }

  Future<void> getUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userEmail = user.email!;
      await fetchRoutes();
      await checkOngoingTrips();
    } else {
      // Handle user not logged in scenario
    }
  }

  Future<void> fetchRoutes() async {
    final snapshot = await FirebaseFirestore.instance.collection('routes').get();
    final List<Map<String, dynamic>> fetchedRoutes = snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'name': doc['name'],
      'startLatitude': doc['startLatitude'],
      'startLongitude': doc['startLongitude'],
      'endLatitude': doc['endLatitude'],
      'endLongitude': doc['endLongitude'],
    })
        .toList();
    setState(() {
      routes = fetchedRoutes;
    });
  }

  Future<void> checkOngoingTrips() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('email', isEqualTo: userEmail)
        .where('endTime', isEqualTo: null)
        .get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        isTripStarted = true;
        tripId = snapshot.docs.first.id;
        selectedRoute = routes.firstWhere((route) => route['id'] == snapshot.docs.first['routeId']);
      });
    }
  }

  Future<void> checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      return;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> getCurrentPosition() async {
    await checkLocationPermission();
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      currentPosition = position;
    });
  }

  Future<void> checkAtStartLocation() async {
    await getCurrentPosition();
    if (selectedRoute == null || currentPosition == null) return;

    double distance = await Geolocator.distanceBetween(
      currentPosition!.latitude, currentPosition!.longitude,
      selectedRoute!['startLatitude'], selectedRoute!['startLongitude'],
    );

    setState(() {
      isAtStartLocation = distance < 100;
    });
  }

  Future<void> checkAtEndLocation() async {
    await getCurrentPosition();
    if (selectedRoute == null || currentPosition == null) return;

    double distance = await Geolocator.distanceBetween(
      currentPosition!.latitude, currentPosition!.longitude,
      selectedRoute!['endLatitude'], selectedRoute!['endLongitude'],
    );

    setState(() {
      isAtEndLocation = distance < 100;
    });
  }

  void startTrip() async {
    if (selectedRoute == null) return;
    DocumentReference tripDoc = await FirebaseFirestore.instance.collection('trips').add({
      'userEmail': userEmail,
      'routeId': selectedRoute!['id'],
      'startLatitude': selectedRoute!['startLatitude'],
      'startLongitude': selectedRoute!['startLongitude'],
      'endLatitude': selectedRoute!['endLatitude'],
      'endLongitude': selectedRoute!['endLongitude'],
      'startTime': Timestamp.now(),
      'endTime': null,
    });
    setState(() {
      isTripStarted = true;
      tripId = tripDoc.id;
    });
  }

  void endTrip() async {
    if (isAtEndLocation && tripId != null) {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'endTime': Timestamp.now(),
      });
      setState(() {
        isTripStarted = false;
        tripId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip completed successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are not at the end location yet'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarr(foodtitle: 'Trip'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<Map<String, dynamic>>(
                hint: Text('Select Route'),
                value: selectedRoute,
                onChanged: isTripStarted ? null : (route) {
                  setState(() {
                    selectedRoute = route;
                    isTripStarted = false;
                    isAtStartLocation = false;
                    isAtEndLocation = false;
                    tripId = null;
                  });
                  checkAtStartLocation();
                },
                items: routes.map((route) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: route,
                    child: Text(route['name'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              if (currentPosition != null)
                Text(
                  'Current Location: ${currentPosition!.latitude}, ${currentPosition!.longitude}',
                  style: TextStyle(fontSize: 16),
                ),
              SizedBox(height: 20),
              if (!isTripStarted)
                ElevatedButton(
                  onPressed: isAtStartLocation ? startTrip : null,
                  child: Text('Start Trip'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.teal,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isTripStarted)
                ElevatedButton(
                  onPressed: endTrip,
                  child: Text('End Trip'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              SizedBox(height: 20),
              if (isTripStarted)
                Text(
                  'Trip in progress...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              if (isAtStartLocation && !isTripStarted)
                Text(
                  'You are at the start location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              if (isAtEndLocation && isTripStarted)
                Text(
                  'You are at the end location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
