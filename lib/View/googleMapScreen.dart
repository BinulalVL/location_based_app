import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:location_based_app/Controller/locationController.dart';
import 'package:http/http.dart' as http;


class GoogleMapScreen extends StatefulWidget {
  GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final LocationController controller = Get.put(LocationController());
  late GooglePlace _googlePlace;
  late GoogleMapController _mapController;

  List<AutocompletePrediction> predictions = [];
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> selectedPlaces = [];

  late LatLng _currentLocation;

  @override
  void initState() {
    super.initState();
    controller.getCurrentLocation();
    _googlePlace = GooglePlace("AIzaSyBHWsgt8_4qvroXx0-rdyyG24OIts0MRJo");
  }

  void _searchPlaces(String query) async {
    if (query.isNotEmpty) {
      final result = await _googlePlace.autocomplete.get(query);
      if (result != null && result.predictions != null) {
        setState(() {
          predictions = result.predictions!;
        });
      }
    } else {
      setState(() {
        predictions = [];
      });
    }
  }

  void _selectPlace(String placeId) async {
    final details = await _googlePlace.details.get(placeId);
    if (details != null && details.result != null) {
      final location = details.result!.geometry!.location!;
      final placeData = {
        'placeId': placeId,
        'name': details.result!.name,
        'address': details.result!.formattedAddress,
        'latitude': location.lat,
        'longitude': location.lng,
      };

      setState(() {
        _markers.add(Marker(
          markerId: MarkerId(placeId),
          position: LatLng(location.lat!, location.lng!),
          infoWindow: InfoWindow(title: details.result!.name),
        ));

        selectedPlaces.add(placeData);
        predictions = [];
        _searchController.clear();
      });

      _mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(location.lat!, location.lng!)),
      );
    }
  }

  void _onMapTapped(LatLng position) {
    final markerId = MarkerId(position.toString());

    setState(() {
      _markers.add(Marker(
        markerId: markerId,
        position: position,
        infoWindow: InfoWindow(title: "Tapped Location"),
      ));

      selectedPlaces.add({
        'placeId': markerId.value,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
    });
    _getPlaceName(position);

  }

  void _onMapLongPressed(LatLng position) {
    setState(() {
      Marker? markerToRemove;
      for (var marker in _markers) {
        final double distance = _calculateDistance(
          position.latitude,
          position.longitude,
          marker.position.latitude,
          marker.position.longitude,
        );

        if (distance < 0.0001) {
          markerToRemove = marker;
          break;
        }
      }

      if (markerToRemove != null) {
        _markers.remove(markerToRemove);

        selectedPlaces.removeWhere((place) =>
            (place['latitude'] - markerToRemove!.position.latitude).abs() <
                0.0001 &&
            (place['longitude'] - markerToRemove.position.longitude).abs() <
                0.0001);
      }
    });
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    return ((lat1 - lat2).abs() + (lng1 - lng2).abs());
  }

  void _moveCamera(LatLng target) {
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 14.0),
      ),
    );
  }

  void _goToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation,
            zoom: 15,
          ),
        ),
      );
    }
  }

  var placenameData;

  Future<void> _getPlaceName(LatLng position) async {
    final String apiKey = 'AIzaSyBHWsgt8_4qvroXx0-rdyyG24OIts0MRJo'; // Replace with your API key
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data);
      setState(() {
        placenameData=data['results'][data.length-1]['formatted_address'];
      });

      if (data['results'].isNotEmpty) {
        final placeName = data['results'][0]['formatted_address'];
        _showPlaceNameDialog(placeName);
      } else {
        _showPlaceNameDialog('No place found at this location');
      }
    } else {
      _showPlaceNameDialog('Failed to get place name');
    }
  }
  void _showPlaceNameDialog(String placeName) {



    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Place Name',),
          content: Text(placeName),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Obx(() {
        if (controller.currentLocation.value == null) {
          return const Center(child: CircularProgressIndicator());
        } else {
          _currentLocation = controller.currentLocation.value!;
          _markers.add(Marker(
            markerId: MarkerId('currentLocation'),
            position: _currentLocation,
            infoWindow: InfoWindow(title: 'Current Location'),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ));

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation,
                  zoom: 15,
                ),
                onMapCreated: (GoogleMapController mapController) {
                  _mapController = mapController;
                },
                onTap: _onMapTapped,
                onLongPress: _onMapLongPressed,
                markers: _markers,
              ),
              Positioned(
                top: 50,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    SizedBox(
                      height: height / 17,
                      child: Container(
                        decoration: BoxDecoration(boxShadow: [
                          new BoxShadow(
                              color: Colors.grey.shade400,
                              blurRadius: 10,
                              spreadRadius: .1)
                        ]),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchPlaces,
                          decoration: InputDecoration(
                            hintText: "Search places",
                            hintStyle: TextStyle(fontSize: 16),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                    if (predictions.isNotEmpty)
                      Container(
                        color: Colors.white,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: predictions.length,
                          itemBuilder: (context, index) {
                            final prediction = predictions[index];
                            return ListTile(
                              title: Text(prediction.description!),
                              onTap: () => _selectPlace(prediction.placeId!),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),


              Positioned(
                bottom: 180,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _goToCurrentLocation,
                  child: Icon(Icons.my_location),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
              ),

              Container(
                child: DraggableScrollableSheet(
                  initialChildSize: 0.2,
                  minChildSize: 0.2,
                  maxChildSize: 0.8,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          Center(
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              width: 40,
                              height: 4,
                              color: Colors.grey,
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'Place Name',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 19),
                            ),
                            subtitle: Text('Details are listed below'),
                          ),
                          ...selectedPlaces.map((place) {
                            return place['name'] == null
                                ? ListTile(
                                    title: Text(placenameData??'Loading...',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        "Lat: ${place['latitude']}, Lng: ${place['longitude']}"),
                                  )
                                : ListTile(
                                    title: Text(" ${place['name']}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text("${place['address']}"),
                                    onTap: () {
                                      print(place);
                                      setState(() {
                                        _mapController.animateCamera(
                                            CameraUpdate.newLatLng(
                                          LatLng(place['latitude'],
                                              place['longitude']),
                                        ));
                                      });
                                    },
                                  );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
