/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dr_shahin_uk/screens/booking_screen.dart';

class BedListScreen extends StatefulWidget {
  const BedListScreen({super.key});

  @override
  BedListScreenState createState() => BedListScreenState();
}

class BedListScreenState extends State<BedListScreen> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('hospitals');
  List<Map<String, dynamic>> hospitals = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initLocationStream();
    _fetchHospitalsRealtime();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _fetchHospitalsRealtime() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> tempHospitals = [];

      if (data != null) {
        final hospitalMap = data as Map<dynamic, dynamic>;
        hospitalMap.forEach((key, value) {
          Map<String, dynamic> hospital = Map<String, dynamic>.from(value);
          hospital['id'] = key;
          tempHospitals.add(hospital);
        });
      }

      if (_currentPosition != null) {
        tempHospitals = tempHospitals.where((hospital) {
          if (hospital['latitude'] != null && hospital['longitude'] != null) {
            double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              hospital['latitude'],
              hospital['longitude'],
            );
            hospital['distance'] = (distance / 1000).toStringAsFixed(2);
            return true;
          }
          return false;
        }).toList();

        tempHospitals.sort((a, b) {
          double distA = double.tryParse(a['distance'] ?? "9999") ?? 9999;
          double distB = double.tryParse(b['distance'] ?? "9999") ?? 9999;
          return distA.compareTo(distB);
        });
      }

      setState(() {
        hospitals = tempHospitals;
      });
    });
  }

  Future<void> _initLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    )).listen((Position position) {
      setState(() => _currentPosition = position);
      _fetchHospitalsRealtime();
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMap(double lat, double lng) async =>
      _launchUrl("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

  Future<void> _launchCaller(String phoneNumber) async =>
      _launchUrl("tel:$phoneNumber");

  Future<void> _launchWebsite(String url) async => _launchUrl(url);

  int _getTotalBeds(dynamic beds) {
    if (beds == null) return 0;
    if (beds is int) return beds;
    if (beds is double) return beds.toInt();
    if (beds is String) return int.tryParse(beds) ?? 0;
    if (beds is Map) {
      return beds.values.fold(0, (prev, value) => prev + _getTotalBeds(value));
    }
    return 0;
  }

  Widget _buildBedCount(dynamic beds) {
    if (beds == null) {
      return const Text("Beds: N/A", style: TextStyle(fontSize: 14));
    }
    if (beds is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: beds.entries.map((entry) {
          int count = _getTotalBeds(entry.value);
          return Text(
            "${entry.key.toUpperCase()} Beds: $count",
            style: TextStyle(
              fontSize: 14,
              color: count == 0 ? Colors.red : Colors.black,
            ),
          );
        }).toList(),
      );
    } else {
      int count = _getTotalBeds(beds);
      return Text(
        "Total Beds: $count",
        style: TextStyle(
          fontSize: 14,
          color: count == 0 ? Colors.red : Colors.black,
        ),
      );
    }
  }

  /// Book a bed and update Firebase in real-time
  void _bookBed(Map<String, dynamic> hospital) async {
    // Find a bed type with available beds
    if (hospital['beds'] is Map) {
      final bedsMap = Map<String, dynamic>.from(hospital['beds']);
      String? bookedBedType;
      bedsMap.forEach((key, value) {
        if (_getTotalBeds(value) > 0 && bookedBedType == null) {
          bookedBedType = key;
        }
      });

      if (bookedBedType != null) {
        final String key = bookedBedType!;
        final bedValue = bedsMap[key];
        if (bedValue is int) {
          bedsMap[key] = bedValue - 1;
        } else if (bedValue is Map) {
          String firstKey = bedValue.keys.first;
          final dynamic firstVal = bedValue[firstKey];
          if (firstVal is int && firstVal > 0) {
            bedValue[firstKey] = firstVal - 1;
          }
        }

        // Update Firebase
        await _dbRef.child(hospital['id']).child('beds').set(bedsMap);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bed booked: $key")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No beds available")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Beds")),
      body: Column(
        children: [
          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Your Location: (${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: hospitals.isEmpty
                ? const Center(child: Text("No hospitals found nearby."))
                : ListView.builder(
                    itemCount: hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = hospitals[index];
                      final totalBeds = _getTotalBeds(hospital['beds']);

                      return Card(
                        margin: const EdgeInsets.all(10),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  hospital['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBedCount(hospital['beds']),
                                    if (hospital.containsKey('distance'))
                                      Text(
                                        "Distance: ${hospital['distance']} km",
                                      ),
                                    Text(
                                      "Contact: ${hospital['contact'] ?? 'N/A'}",
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.map,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _launchMap(
                                        hospital['latitude'],
                                        hospital['longitude'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _launchCaller(
                                        hospital['contact'] ?? "",
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.web,
                                        color: Colors.orange,
                                      ),
                                      onPressed: () => _launchWebsite(
                                        hospital['website'] ?? "",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.local_hotel,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  "Book Bed ($totalBeds)",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: totalBeds > 0
                                    ? () => _bookBed(hospital)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
*/
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dr_shahin_uk/screens/booking_screen.dart';

class BedListScreen extends StatefulWidget {
  const BedListScreen({super.key});

  @override
  BedListScreenState createState() => BedListScreenState();
}

class BedListScreenState extends State<BedListScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'hospitals',
  );
  List<Map<String, dynamic>> hospitals = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initLocationStream();
    _fetchHospitalsRealtime();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Fetch hospitals data live from Firebase
  void _fetchHospitalsRealtime() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> tempHospitals = [];

      if (data != null) {
        final hospitalMap = data as Map<dynamic, dynamic>;
        hospitalMap.forEach((key, value) {
          Map<String, dynamic> hospital = Map<String, dynamic>.from(value);
          hospital['id'] = key;
          tempHospitals.add(hospital);
        });
      }

      /// Sort by distance
      if (_currentPosition != null) {
        tempHospitals = tempHospitals.where((hospital) {
          double? hLat = hospital['latitude'];
          double? hLng = hospital['longitude'];

          if (hLat != null && hLng != null) {
            double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              hLat,
              hLng,
            );

            hospital['distance'] = (distance / 1000).toStringAsFixed(2);
            return true;
          }
          return false;
        }).toList();

        tempHospitals.sort((a, b) {
          double distA = double.tryParse(a['distance'] ?? "9999") ?? 9999;
          double distB = double.tryParse(b['distance'] ?? "9999") ?? 9999;
          return distA.compareTo(distB);
        });
      }

      setState(() {
        hospitals = tempHospitals;
      });
    });
  }

  /// Track location
  Future<void> _initLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
          ),
        ).listen((Position position) {
          setState(() => _currentPosition = position);
          _fetchHospitalsRealtime();
        });
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchMap(double lat, double lng) async {
    // Use geo: scheme first to open Google Maps app directly
    final Uri geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng(Hospital)");
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to browser if Maps app is not available
      final Uri webUri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(
          // ignore: use_build_context_synchronously
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not open map.")));
      }
    }
  }

  Future<void> _launchCaller(String phoneNumber) async =>
      _launchUrl("tel:$phoneNumber");

  Future<void> _launchWebsite(String url) async => _launchUrl(url);

  /// Bed count logic
  int _getTotalBeds(dynamic beds) {
    if (beds == null) return 0;
    if (beds is int) return beds;
    if (beds is double) return beds.toInt();
    if (beds is String) return int.tryParse(beds) ?? 0;
    if (beds is Map) {
      return beds.values.fold(0, (prev, value) => prev + _getTotalBeds(value));
    }
    return 0;
  }

  Widget _buildBedCount(dynamic beds) {
    if (beds == null) {
      return const Text("Beds: N/A", style: TextStyle(fontSize: 14));
    }
    int count = _getTotalBeds(beds);
    return Text(
      "Total Beds: $count",
      style: TextStyle(
        fontSize: 14,
        color: count == 0 ? Colors.red : Colors.black,
      ),
    );
  }

  /// GO TO BOOKING SCREEN
  void _bookBed(Map<String, dynamic> hospital) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BedBookingScreen(hospital: hospital),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Beds")),
      body: Column(
        children: [
          if (_currentPosition != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Your Location: (${_currentPosition!.latitude.toStringAsFixed(4)}, "
                "${_currentPosition!.longitude.toStringAsFixed(4)})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: hospitals.isEmpty
                ? const Center(child: Text("No hospitals found nearby."))
                : ListView.builder(
                    itemCount: hospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = hospitals[index];
                      final totalBeds = _getTotalBeds(
                        hospital['availableBeds'],
                      );

                      return Card(
                        margin: const EdgeInsets.all(10),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  hospital['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBedCount(hospital['availableBeds']),
                                    if (hospital.containsKey('distance'))
                                      Text(
                                        "Distance: ${hospital['distance']} km",
                                      ),
                                    Text(
                                      "Contact: ${hospital['phone'] ?? 'N/A'}",
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.map,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _launchMap(
                                        hospital['latitude'],
                                        hospital['longitude'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _launchCaller(
                                        hospital['phone'] ?? "",
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.web,
                                        color: Colors.orange,
                                      ),
                                      onPressed: () => _launchWebsite(
                                        hospital['website'] ?? "",
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              /// BOOK BED BUTTON
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.local_hotel,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  "Book Bed ($totalBeds)",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: totalBeds > 0
                                    ? () => _bookBed(hospital)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
