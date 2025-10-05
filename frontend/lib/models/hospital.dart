import 'dart:math';

class Hospital {
  final String id;
  final String name;
  final String category;
  final String discipline;
  final String address;
  final String state;
  final String district;
  final String pincode;
  final String telephone;
  final String emergencyNum;
  final String bloodbankPhone;
  final String email;
  final String website;
  final List<String> specialties;
  final List<String> facilities;
  final String accreditation;
  final String ayush;
  final int totalBeds;
  final int availableBeds;
  final int privateWards;
  final double latitude;
  final double longitude;
  final String? locationCoordinates;
  final String? location;

  Hospital({
    required this.id,
    required this.name,
    required this.category,
    required this.discipline,
    required this.address,
    required this.state,
    required this.district,
    required this.pincode,
    required this.telephone,
    required this.emergencyNum,
    required this.bloodbankPhone,
    required this.email,
    required this.website,
    required this.specialties,
    required this.facilities,
    required this.accreditation,
    required this.ayush,
    required this.totalBeds,
    required this.availableBeds,
    required this.privateWards,
    required this.latitude,
    required this.longitude,
    this.locationCoordinates,
    this.location,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    // Handle coordinates from multiple possible sources
    double lat = 0.0;
    double lng = 0.0;

    // Try to get coordinates from MongoDB location field first (backend format)
    if (json['location'] != null && json['location'] is Map) {
      final loc = json['location'];
      if (loc['type'] == 'Point' &&
          loc['coordinates'] is List &&
          loc['coordinates'].length == 2) {
        lng = _parseDouble(loc['coordinates'][0]);
        lat = _parseDouble(loc['coordinates'][1]);
      }
    }

    // Fallback to other coordinate fields
    if (lat == 0.0 && lng == 0.0) {
      if (json['latitude'] != null && json['longitude'] != null) {
        lat = _parseDouble(json['latitude']);
        lng = _parseDouble(json['longitude']);
      } else if (json['Location_Coordinates'] != null &&
          json['Location_Coordinates'].toString().isNotEmpty) {
        final coords = json['Location_Coordinates'].toString().split(',');
        if (coords.length >= 2) {
          lat = _parseDouble(coords[0].trim());
          lng = _parseDouble(coords[1].trim());
        }
      } else if (json['locationCoordinates'] != null &&
          json['locationCoordinates'].toString().isNotEmpty) {
        final coords = json['locationCoordinates'].toString().split(',');
        if (coords.length >= 2) {
          lat = _parseDouble(coords[0].trim());
          lng = _parseDouble(coords[1].trim());
        }
      }
    }

    return Hospital(
      id: json['_id']?.toString() ??
          json['Sr_No']?.toString() ??
          json['srNo']?.toString() ??
          '',
      // Backend sends 'name' (lowercase), Excel has 'Hospital_Name'
      name: json['name']?.toString() ??
          json['Hospital_Name']?.toString() ??
          json['hospitalName']?.toString() ??
          'Unknown Hospital',
      category: json['category']?.toString() ??
          json['Hospital_Category']?.toString() ??
          json['hospitalCategory']?.toString() ??
          'General',
      discipline: json['discipline']?.toString() ??
          json['Discipline_Systems_of_Medicine']?.toString() ??
          json['disciplineSystemsOfMedicine']?.toString() ??
          '',
      address: json['address']?.toString() ??
          json['Address_Original_First_Line']?.toString() ??
          json['addressOriginalFirstLine']?.toString() ??
          '',
      state: json['state']?.toString() ?? json['State']?.toString() ?? '',
      district:
          json['district']?.toString() ?? json['District']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? json['Pincode']?.toString() ?? '',
      telephone:
          json['telephone']?.toString() ?? json['Telephone']?.toString() ?? '',
      emergencyNum: json['emergencyNum']?.toString() ??
          json['Emergency_Num']?.toString() ??
          '',
      bloodbankPhone: json['bloodbankPhone']?.toString() ??
          json['Bloodbank_Phone_No']?.toString() ??
          '',
      email: json['email']?.toString() ??
          json['Hospital_Primary_Email_Id']?.toString() ??
          json['hospitalPrimaryEmailId']?.toString() ??
          '',
      website: json['website']?.toString() ?? json['Website']?.toString() ?? '',
      specialties:
          _parseStringToList(json['specialties'] ?? json['Specialties']),
      facilities: _parseStringToList(json['facilities'] ?? json['Facilities']),
      accreditation: json['accreditation']?.toString() ??
          json['Accreditation']?.toString() ??
          '',
      ayush: json['ayush']?.toString() ?? json['Ayush']?.toString() ?? '',
      totalBeds: _parseInt(json['totalBeds'] ??
              json['Total_Num_Beds'] ??
              json['totalNumBeds']) ??
          0,
      availableBeds:
          _parseInt(json['availableBeds'] ?? json['Available_Beds']) ?? 0,
      privateWards: _parseInt(json['privateWards'] ??
              json['Number_Private_Wards'] ??
              json['numberPrivateWards']) ??
          0,
      latitude: lat,
      longitude: lng,
      locationCoordinates: json['Location_Coordinates']?.toString() ??
          json['locationCoordinates']?.toString(),
      location: json['Location']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static List<String> _parseStringToList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    String str = value.toString();
    if (str.isEmpty) return [];

    // Handle comma-separated values
    return str
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'discipline': discipline,
      'address': address,
      'state': state,
      'district': district,
      'pincode': pincode,
      'telephone': telephone,
      'emergencyNum': emergencyNum,
      'bloodbankPhone': bloodbankPhone,
      'email': email,
      'website': website,
      'specialties': specialties,
      'facilities': facilities,
      'accreditation': accreditation,
      'ayush': ayush,
      'totalBeds': totalBeds,
      'availableBeds': availableBeds,
      'privateWards': privateWards,
      'latitude': latitude,
      'longitude': longitude,
      'locationCoordinates': locationCoordinates,
      'location': location,
    };
  }

  // Calculate distance from user's location in kilometers
  double distanceFrom(double userLat, double userLng) {
    if (latitude == 0 && longitude == 0) return double.infinity;

    const double earthRadius = 6371; // Earth's radius in kilometers
    double latDiff = _degreesToRadians(latitude - userLat);
    double lngDiff = _degreesToRadians(longitude - userLng);

    double a = sin(latDiff / 2) * sin(latDiff / 2) +
        cos(_degreesToRadians(userLat)) *
            cos(_degreesToRadians(latitude)) *
            sin(lngDiff / 2) *
            sin(lngDiff / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get formatted address
  String get fullAddress {
    List<String> addressParts = [];
    if (address.isNotEmpty) addressParts.add(address);
    if (district.isNotEmpty) addressParts.add(district);
    if (state.isNotEmpty) addressParts.add(state);
    if (pincode.isNotEmpty) addressParts.add(pincode);
    return addressParts.join(', ');
  }

  // Check if hospital has valid coordinates
  bool get hasValidCoordinates {
    return latitude != 0 && longitude != 0;
  }

  // Get availability status
  String get availabilityStatus {
    if (availableBeds > 20) return 'High Availability';
    if (availableBeds > 5) return 'Medium Availability';
    if (availableBeds > 0) return 'Low Availability';
    return 'No Beds Available';
  }

  // Get category color helper
  String get categoryColorCode {
    switch (category.toLowerCase()) {
      case 'government':
      case 'public/ government':
        return 'green';
      case 'private':
        return 'blue';
      case 'charitable':
        return 'orange';
      default:
        return 'blue';
    }
  }

  // Check if hospital has emergency services
  bool get hasEmergencyServices {
    return emergencyNum.isNotEmpty ||
        facilities.any((f) => f.toLowerCase().contains('emergency')) ||
        specialties.any((s) => s.toLowerCase().contains('emergency'));
  }

  // Check if hospital has blood bank
  bool get hasBloodBank {
    return bloodbankPhone.isNotEmpty ||
        facilities.any((f) => f.toLowerCase().contains('blood bank'));
  }

  @override
  String toString() {
    return 'Hospital(id: $id, name: $name, state: $state, district: $district, '
        'coordinates: ($latitude, $longitude), beds: $availableBeds/$totalBeds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hospital && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
