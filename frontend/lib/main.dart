import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'models/hospital.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HospitalProvider()),
      ],
      child: MaterialApp(
        title: 'Hospital Finder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E86AB),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HospitalProvider extends ChangeNotifier {
  List<Hospital> _hospitals = [];
  List<Hospital> _filteredHospitals = [];
  bool _loading = false;
  String _selectedState = '';
  String _selectedDistrict = '';
  String _searchQuery = '';

  List<Hospital> get hospitals => _hospitals;
  List<Hospital> get filteredHospitals => _filteredHospitals;
  bool get loading => _loading;
  String get selectedState => _selectedState;
  String get selectedDistrict => _selectedDistrict;
  String get searchQuery => _searchQuery;

  // Fixed: Use Future to avoid calling setState during build
  Future<void> setLoadingAsync(bool value) async {
    if (_loading != value) {
      _loading = value;
      await Future.microtask(() => notifyListeners());
    }
  }

  void setLoading(bool value) {
    if (_loading != value) {
      _loading = value;
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void setHospitals(List<Hospital> hospitals) {
    _hospitals = hospitals;
    _filteredHospitals = hospitals;
    notifyListeners();
  }

void setSearchQuery(String query) {
  if (_searchQuery == query) return; // Avoid unnecessary updates
  _searchQuery = query;
  _filterHospitals();
  // Debounce notifications for search
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifyListeners();
  });
}

void setSelectedState(String state) {
  if (_selectedState == state) return; // Avoid unnecessary updates
  _selectedState = state;
  _selectedDistrict = '';
  _filterHospitals();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifyListeners();
  });
}

void setSelectedDistrict(String district) {
  if (_selectedDistrict == district) return; // Avoid unnecessary updates
  _selectedDistrict = district;
  _filterHospitals();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifyListeners();
  });
}

void _filterHospitals() {
  // Use more efficient filtering without unnecessary list copies
  final query = _searchQuery.toLowerCase();
  final state = _selectedState.toLowerCase();
  final district = _selectedDistrict.toLowerCase();
  
  _filteredHospitals = _hospitals.where((hospital) {
    // Short-circuit evaluation for better performance
    if (_selectedState.isNotEmpty && 
        hospital.state.toLowerCase() != state) {
      return false;
    }

    if (_selectedDistrict.isNotEmpty && 
        hospital.district.toLowerCase() != district) {
      return false;
    }

    if (_searchQuery.isNotEmpty) {
      final nameMatch = hospital.name.toLowerCase().contains(query);
      final addressMatch = hospital.address.toLowerCase().contains(query);
      return nameMatch || addressMatch;
    }

    return true;
  }).toList();
}

  void clearFilters() {
    _selectedState = '';
    _selectedDistrict = '';
    _searchQuery = '';
    _filteredHospitals = _hospitals;
    notifyListeners();
  }

  List<String> get states {
    return _hospitals.map((h) => h.state).toSet().toList()..sort();
  }

  List<String> getDistricts(String state) {
    return _hospitals
        .where((h) => h.state.toLowerCase() == state.toLowerCase())
        .map((h) => h.district)
        .toSet()
        .toList()
      ..sort();
  }

  // Get nearby hospitals based on user location
  List<Hospital> getNearbyHospitals(double userLat, double userLng, {double radiusKm = 50}) {
    final nearbyHospitals = _hospitals.where((hospital) {
      if (hospital.latitude == 0 || hospital.longitude == 0) return false;
      final distance = hospital.distanceFrom(userLat, userLng);
      return distance <= radiusKm;
    }).toList();

    // Sort by distance
    nearbyHospitals.sort((a, b) {
      final distanceA = a.distanceFrom(userLat, userLng);
      final distanceB = b.distanceFrom(userLat, userLng);
      return distanceA.compareTo(distanceB);
    });

    return nearbyHospitals;
  }
}