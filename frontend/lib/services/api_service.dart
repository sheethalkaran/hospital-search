import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hospital.dart';

class ApiService {
  // Base URLs for different platforms
  static const List<String> baseUrls = [
    'http://localhost:3000/api', // For iOS simulator
    'http://10.0.2.2:3000/api', // For Android emulator
    'http://127.0.0.1:3000/api', // Alternative localhost
    // Add your computer's IP for physical device testing
    // 'http://192.168.1.XXX:3000/api',
  ];

  static String? _workingBaseUrl;

  // Find working base URL by testing connectivity
  static Future<String> _getWorkingBaseUrl() async {
    if (_workingBaseUrl != null) {
      return _workingBaseUrl!;
    }

    for (String baseUrl in baseUrls) {
      try {
        print('🔍 Testing connection to: $baseUrl');
        final response = await http.get(
          Uri.parse('$baseUrl/health'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print('✅ Successfully connected to: $baseUrl');
          final data = json.decode(response.body);
          print('📊 Server response: ${data['message']}');
          print('📊 Total hospitals in DB: ${data['totalHospitals']}');
          _workingBaseUrl = baseUrl;
          return baseUrl;
        }
      } catch (e) {
        print('❌ Failed to connect to: $baseUrl - ${e.toString()}');
        continue;
      }
    }

    throw Exception(
        '❌ Could not connect to any backend server. Please ensure:\n'
        '1. Backend server is running (npm run dev)\n'
        '2. MongoDB is connected\n'
        '3. Correct IP address is used for physical devices');
  }

  // Get ALL hospitals from MongoDB (no limit)
  static Future<List<Hospital>> getAllHospitals() async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final url = '$baseUrl/hospitals';

      print('📡 Fetching ALL hospitals from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
          const Duration(seconds: 30)); // Increased timeout for large datasets

      print('📈 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        print('📊 Response length: ${responseBody.length} characters');

        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }

        List<dynamic> data;
        try {
          var decoded = json.decode(responseBody);

          if (decoded is List) {
            data = decoded;
          } else if (decoded is Map && decoded.containsKey('data')) {
            data = decoded['data'] as List<dynamic>;
          } else if (decoded is Map && decoded.containsKey('hospitals')) {
            data = decoded['hospitals'] as List<dynamic>;
          } else if (decoded is Map) {
            data = [decoded];
          } else {
            throw Exception(
                'Unexpected response format: ${decoded.runtimeType}');
          }
        } catch (e) {
          throw Exception('Failed to parse JSON response: $e');
        }

        print('🏥 Found ${data.length} hospitals in response');

        if (data.isEmpty) {
          print('⚠️ No hospitals found in database');
          return [];
        }

        // Convert to Hospital objects
        List<Hospital> hospitals = [];
        for (int i = 0; i < data.length; i++) {
          try {
            final hospitalData = data[i] as Map<String, dynamic>;
            final hospital = Hospital.fromJson(hospitalData);
            hospitals.add(hospital);

            // Log first few hospitals for debugging
            if (i < 3) {
              print(
                  '🏥 Hospital ${i + 1}: ${hospital.name} (${hospital.state})');
            }
          } catch (e) {
            print('⚠️ Failed to parse hospital at index $i: $e');
            continue;
          }
        }

        print('✅ Successfully parsed ${hospitals.length} hospitals');
        return hospitals;
      } else {
        final errorBody = response.body;
        print('❌ Server error ${response.statusCode}: $errorBody');
        throw Exception('Server error ${response.statusCode}: $errorBody');
      }
    } catch (e) {
      print('❌ Error in getAllHospitals: ${e.toString()}');
      rethrow;
    }
  }

  // Get nearby hospitals (NO LIMIT - returns all within radius)
  static Future<List<Hospital>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    double radius = 50,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final url =
          '$baseUrl/hospitals/nearby?lat=$latitude&lng=$longitude&radius=$radius';

      print('📡 Fetching nearby hospitals from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var decoded = json.decode(response.body);
        List<dynamic> data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'] as List<dynamic>;
        } else if (decoded is Map && decoded.containsKey('hospitals')) {
          data = decoded['hospitals'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format');
        }

        print('🎯 Found ${data.length} nearby hospitals');
        return data.map((json) => Hospital.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load nearby hospitals: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching nearby hospitals: $e');
      rethrow;
    }
  }

  // Search hospitals with filters (NO LIMIT - searches entire dataset)
  static Future<List<Hospital>> searchHospitals({
    String? state,
    String? district,
    String? name,
    String? category,
    String? specialty,
    int? minAvailableBeds,
    String? searchText,
  }) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();

      final queryParams = <String>[];
      if (state != null && state.isNotEmpty) {
        queryParams.add('state=${Uri.encodeComponent(state)}');
      }
      if (district != null && district.isNotEmpty) {
        queryParams.add('district=${Uri.encodeComponent(district)}');
      }
      if (name != null && name.isNotEmpty) {
        queryParams.add('name=${Uri.encodeComponent(name)}');
      }
      if (category != null && category.isNotEmpty) {
        queryParams.add('category=${Uri.encodeComponent(category)}');
      }
      if (specialty != null && specialty.isNotEmpty) {
        queryParams.add('speciality=${Uri.encodeComponent(specialty)}');
      }
      if (minAvailableBeds != null) {
        queryParams.add('availableBeds=$minAvailableBeds');
      }
      if (searchText != null && searchText.isNotEmpty) {
        queryParams.add('searchText=${Uri.encodeComponent(searchText)}');
      }

      final queryString = queryParams.join('&');
      final url = '$baseUrl/hospitals/search?$queryString';

      // Removed verbose print statement to prevent UI hangs

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var decoded = json.decode(response.body);
        List<dynamic> data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'] as List<dynamic>;
        } else if (decoded is Map && decoded.containsKey('hospitals')) {
          data = decoded['hospitals'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response format');
        }

        // Removed verbose print statement to prevent excessive logging
        return data.map((json) => Hospital.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to search hospitals: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error searching hospitals: $e');
      rethrow;
    }
  }

  // Get hospital by ID
  static Future<Hospital> getHospitalById(String id) async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final url = '$baseUrl/hospitals/$id';

      // Removed verbose print statement to prevent excessive logging

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        return Hospital.fromJson(data);
      } else {
        throw Exception('Hospital not found: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching hospital details: $e');
      rethrow;
    }
  }

  // Check server status and MongoDB connection
  static Future<Map<String, dynamic>> checkServerStatus() async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': 'connected',
          'message': data['message'] ?? 'Server is running',
          'mongodb': data['mongodb'] ?? 'unknown',
          'totalHospitals': data['totalHospitals'] ?? 0,
          'version': data['version'] ?? '1.0.0',
          'baseUrl': baseUrl,
        };
      } else {
        return {
          'status': 'error',
          'message': 'Server returned ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Server not reachable: $e',
      };
    }
  }

  // Get hospital statistics
  static Future<Map<String, dynamic>> getHospitalStats() async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/hospitals/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching hospital stats: $e');
      rethrow;
    }
  }

  // Reset connection (force reconnection)
  static void resetConnection() {
    print('🔄 Resetting API connection...');
    _workingBaseUrl = null;
  }

  // Test connection to all URLs
  static Future<Map<String, bool>> testAllConnections() async {
    Map<String, bool> results = {};

    for (String baseUrl in baseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));

        results[baseUrl] = response.statusCode == 200;
      } catch (e) {
        results[baseUrl] = false;
      }
    }

    return results;
  }
}
