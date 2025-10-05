import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hospital.dart';
import 'hospital_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Hospital> hospitals;
  final Position? currentPosition;

  const MapScreen({
    super.key,
    required this.hospitals,
    this.currentPosition,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> 
    with TickerProviderStateMixin {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  Hospital? _selectedHospital;
  bool _showHospitalCard = false;
  late AnimationController _cardAnimationController;
  late AnimationController _fabAnimationController;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _fabRotateAnimation;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _cardScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.elasticOut,
    ));

    _fabRotateAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _createMarkers();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _createMarkers() {
    Set<Marker> markers = {};

    // Add user location marker if available
    if (widget.currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current GPS position',
          ),
        ),
      );
    }

    // Add hospital markers
    final filteredHospitals = _getFilteredHospitals();
    for (var hospital in filteredHospitals) {
      if (hospital.latitude != 0 && hospital.longitude != 0) {
        markers.add(
          Marker(
            markerId: MarkerId(hospital.id),
            position: LatLng(hospital.latitude, hospital.longitude),
            icon: _getMarkerIcon(hospital),
            infoWindow: InfoWindow(
              title: hospital.name,
              snippet: '${hospital.availableBeds} beds available • ${hospital.category}',
            ),
            onTap: () => _onMarkerTapped(hospital),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  List<Hospital> _getFilteredHospitals() {
    switch (_selectedFilter) {
      case 'available':
        return widget.hospitals.where((h) => h.availableBeds > 0).toList();
      case 'government':
        return widget.hospitals
            .where((h) => h.category.toLowerCase().contains('government') || 
                        h.category.toLowerCase().contains('public'))
            .toList();
      case 'private':
        return widget.hospitals
            .where((h) => h.category.toLowerCase().contains('private'))
            .toList();
      default:
        return widget.hospitals;
    }
  }

  BitmapDescriptor _getMarkerIcon(Hospital hospital) {
    if (hospital.availableBeds > 0) {
      if (hospital.category.toLowerCase().contains('government') ||
          hospital.category.toLowerCase().contains('public')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (hospital.category.toLowerCase().contains('private')) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _onMarkerTapped(Hospital hospital) {
    setState(() {
      _selectedHospital = hospital;
      _showHospitalCard = true;
    });
    _cardAnimationController.forward();
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _fitMapToMarkers();
    
    // Set custom map style for premium look
    _controller?.setMapStyle('''
    [
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#e9e9e9"
          },
          {
            "lightness": 17
          }
        ]
      },
      {
        "featureType": "landscape",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#f5f5f5"
          },
          {
            "lightness": 20
          }
        ]
      }
    ]
    ''');
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        120.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: widget.currentPosition != null
                  ? LatLng(
                      widget.currentPosition!.latitude,
                      widget.currentPosition!.longitude,
                    )
                  : const LatLng(20.5937, 78.9629),
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            buildingsEnabled: true,
            trafficEnabled: false,
            onTap: (_) {
              if (_showHospitalCard) {
                _cardAnimationController.reverse().then((_) {
                  setState(() {
                    _showHospitalCard = false;
                    _selectedHospital = null;
                  });
                });
              }
            },
          ),
          
          // Enhanced Header
          _buildEnhancedHeader(),
          
          // Filter Panel
          _buildFilterPanel(),
          
          // Legend
          _buildLegend(),
          
          // Enhanced FABs
          _buildEnhancedFABs(),
          
          // Hospital Card
          if (_showHospitalCard && _selectedHospital != null)
            _buildAnimatedHospitalCard(_selectedHospital!),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hospital Map',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${_getFilteredHospitals().length} hospitals found',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Positioned(
      top: 140,
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildFilterChip('all', 'All', Icons.map_rounded),
            _buildFilterChip('available', 'Available', Icons.check_circle_rounded),
            _buildFilterChip('government', 'Public', Icons.account_balance_rounded),
            _buildFilterChip('private', 'Private', Icons.business_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
          _createMarkers();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      top: 220,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legend',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            _buildLegendItem(Colors.green, 'Government/Public'),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.blue, 'Private'),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.orange, 'Charitable'),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.red, 'No Beds'),
            const SizedBox(height: 8),
            _buildLegendItem(Colors.lightBlue, 'Your Location'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedFABs() {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Positioned(
          bottom: _showHospitalCard ? 240 : 120,
          right: 20,
          child: Column(
            children: [
              // My Location FAB
              Transform.rotate(
                angle: _fabRotateAnimation.value * 2 * 3.14159,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "location",
                    mini: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    onPressed: _goToMyLocation,
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Refresh FAB
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: "refresh",
                  mini: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: () {
                    _createMarkers();
                    _fitMapToMarkers();
                  },
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedHospitalCard(Hospital hospital) {
    final distance = widget.currentPosition != null
        ? hospital.distanceFrom(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          )
        : null;

    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _cardSlideAnimation.value * MediaQuery.of(context).size.height * 0.5,
          child: Transform.scale(
            scale: _cardScaleAnimation.value,
            child: Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF8FAFC),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getCategoryColor(hospital.category),
                                  _getCategoryColor(hospital.category).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(hospital.category),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hospital.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(hospital.category).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hospital.category,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _getCategoryColor(hospital.category),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          IconButton(
                            onPressed: () {
                              _cardAnimationController.reverse().then((_) {
                                setState(() {
                                  _showHospitalCard = false;
                                  _selectedHospital = null;
                                });
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Address and Distance
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${hospital.address}, ${hospital.district}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distance != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bed Information
                      Row(
                        children: [
                          _buildQuickStat(
                            icon: Icons.bed_rounded,
                            label: 'Total',
                            value: hospital.totalBeds.toString(),
                            color: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickStat(
                            icon: Icons.check_circle_rounded,
                            label: 'Available',
                            value: hospital.availableBeds.toString(),
                            color: hospital.availableBeds > 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Action Buttons
                      Row(
                        children: [
                          if (hospital.telephone.isNotEmpty)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(hospital.telephone),
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Call',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                          
                          if (hospital.telephone.isNotEmpty)
                            const SizedBox(width: 12),
                          
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF667EEA),
                                  width: 2,
                                ),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          HospitalDetailScreen(
                                        hospital: hospital,
                                        currentPosition: widget.currentPosition,
                                      ),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return SlideTransition(
                                          position: animation.drive(
                                            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                                .chain(CurveTween(curve: Curves.easeInOutCubic)),
                                          ),
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 300),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.info_rounded,
                                  color: Color(0xFF667EEA),
                                  size: 18,
                                ),
                                label: Text(
                                  'Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF667EEA),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'government':
      case 'public/ government':
        return const Color(0xFF059669);
      case 'private':
        return const Color(0xFF1D4ED8);
      case 'charitable':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF667EEA);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'government':
      case 'public/ government':
        return Icons.account_balance_rounded;
      case 'private':
        return Icons.business_rounded;
      case 'charitable':
        return Icons.favorite_rounded;
      default:
        return Icons.local_hospital_rounded;
    }
  }

  void _goToMyLocation() {
    if (widget.currentPosition != null) {
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.currentPosition!.latitude,
              widget.currentPosition!.longitude,
            ),
            zoom: 16,
          ),
        ),
      );
      _fabAnimationController.forward().then((_) {
        _fabAnimationController.reverse();
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    
  }
}