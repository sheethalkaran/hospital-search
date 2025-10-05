import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  String? _error;
  bool _serviceEnabled = false;
  LocationPermission _permission = LocationPermission.denied;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String? get error => _error;
  bool get serviceEnabled => _serviceEnabled;
  LocationPermission get permission => _permission;

  // Initialize location service
  Future<void> initialize() async {
    await _checkLocationService();
    await _checkPermissions();
  }

  // Check if location services are enabled
  Future<void> _checkLocationService() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      _error = 'Location services are disabled. Please enable them in settings.';
    }
    notifyListeners();
  }

  // Check and request location permissions
  Future<void> _checkPermissions() async {
    _permission = await Geolocator.checkPermission();
    
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }
    
    if (_permission == LocationPermission.denied) {
      _error = 'Location permissions are denied. Please grant location access.';
      notifyListeners();
      return;
    }

    if (_permission == LocationPermission.deniedForever) {
      _error = 'Location permissions are permanently denied. Please enable them in app settings.';
      notifyListeners();
      return;
    }

    _error = null;
    notifyListeners();
  }

  // Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      _error = null;
      
      // Re-check permissions and service
      await _checkLocationService();
      await _checkPermissions();
      
      if (!_serviceEnabled || _permission == LocationPermission.denied || _permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position with timeout
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      print('Location obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      notifyListeners();
      return _currentPosition;
      
    } catch (e) {
      _error = 'Failed to get location: ${e.toString()}';
      print('Location error: $e');
      notifyListeners();
      return null;
    }
  }

  // Start real-time location tracking
  Future<bool> startLocationTracking() async {
    if (_isTracking) {
      print('Location tracking already started');
      return true;
    }

    try {
      _error = null;
      
      // Get initial location
      final initialPosition = await getCurrentLocation();
      if (initialPosition == null) {
        print('Failed to get initial location');
        return false;
      }

      // Start location stream with optimized settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
        timeLimit: Duration(seconds: 10),
      );

      print('Starting location tracking...');
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          print('New position: ${position.latitude}, ${position.longitude}');
          _currentPosition = position;
          _isTracking = true;
          _error = null;
          notifyListeners();
        },
        onError: (error) {
          print('Location stream error: $error');
          _error = 'Location tracking error: $error';
          _isTracking = false;
          notifyListeners();
        },
        cancelOnError: false,
      );

      _isTracking = true;
      print('Location tracking started successfully');
      notifyListeners();
      return true;

    } catch (e) {
      print('Failed to start location tracking: $e');
      _error = 'Failed to start location tracking: $e';
      _isTracking = false;
      notifyListeners();
      return false;
    }
  }

  // Stop location tracking
  void stopLocationTracking() {
    print('Stopping location tracking...');
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
  }

  // Calculate distance between two points in kilometers
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Convert to km
  }

  // Get distance from current location to a point
  double? getDistanceFromCurrent(double lat, double lng) {
    if (_currentPosition == null) return null;
    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  // Get bearing from current location to a point
  double? getBearingFromCurrent(double lat, double lng) {
    if (_currentPosition == null) return null;
    return Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  // Open device location settings
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      print('Failed to open location settings: $e');
    }
  }

  // Open app settings
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      print('Failed to open app settings: $e');
    }
  }

  // Check if location permission is granted
  bool get hasLocationPermission {
    return _permission == LocationPermission.always || 
           _permission == LocationPermission.whileInUse;
  }

  // Get location permission status string
  String get permissionStatus {
    switch (_permission) {
      case LocationPermission.always:
        return 'Always allowed';
      case LocationPermission.whileInUse:
        return 'While using app';
      case LocationPermission.denied:
        return 'Denied';
      case LocationPermission.deniedForever:
        return 'Permanently denied';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine';
    }
  }

  // Refresh location data
  Future<void> refreshLocation() async {
    await getCurrentLocation();
  }

  @override
  void dispose() {
    print('Disposing LocationService...');
    stopLocationTracking();
    super.dispose();
  }
}