import 'package:emergency_app/Provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

class LocationContainer extends StatelessWidget {
  const LocationContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final Position? position = locationProvider.currentPosition;
    final String error = locationProvider.locationError;
    final bool isLoading = locationProvider.isLoading;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Show loading spinner when fetching location
        if (isLoading) const CircularProgressIndicator(),

        // If an error occurred, display the error message
        if (error.isNotEmpty)
          Text(
            error,
            style: const TextStyle(color: Colors.red),
          ),

        // If the location is available, display it
        if (!isLoading && position != null && error == '')
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Center(
                child: Text(
                  "Location Fetched Successfully",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

        // Default state when waiting for location
        if (!isLoading && position == null && error.isEmpty)
          const Text('Waiting for location...'),

        const SizedBox(height: 16),
      ],
    );
  }
}
