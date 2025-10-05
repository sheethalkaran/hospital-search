import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hospital.dart';

class HospitalCard extends StatefulWidget {
  final Hospital hospital;
  final Position? currentPosition;
  final VoidCallback onTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    this.currentPosition,
    required this.onTap,
  });

  @override
  State<HospitalCard> createState() => _HospitalCardState();
}

class _HospitalCardState extends State<HospitalCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = widget.currentPosition != null
        ? widget.hospital.distanceFrom(
            widget.currentPosition!.latitude, 
            widget.currentPosition!.longitude,
          )
        : null;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12), // Reduced from 20
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16), // Reduced from 24
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: (_) {
                    setState(() => _isPressed = true);
                    _animationController.forward();
                  },
                  onTapUp: (_) {
                    setState(() => _isPressed = false);
                    _animationController.reverse();
                  },
                  onTapCancel: () {
                    setState(() => _isPressed = false);
                    _animationController.reverse();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16), // Reduced from 24
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(distance),
                          const SizedBox(height: 12), // Reduced from 20
                          _buildLocationInfo(),
                          const SizedBox(height: 12), // Reduced from 16
                          _buildBedInfo(),
                          const SizedBox(height: 12), // Reduced from 16
                          if (widget.hospital.specialties.isNotEmpty) ...[
                            _buildSpecialties(),
                            const SizedBox(height: 12), // Reduced from 20
                          ],
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double? distance) {
    return Row(
      children: [
        // Compact Hospital Icon
        Container(
          padding: const EdgeInsets.all(10), // Reduced from 16
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getCategoryColor(),
                _getCategoryColor().withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12), // Reduced from 20
            boxShadow: [
              BoxShadow(
                color: _getCategoryColor().withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getCategoryIcon(),
            color: Colors.white,
            size: 20, // Reduced from 28
          ),
        ),
        const SizedBox(width: 12), // Reduced from 16
        
        // Hospital Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hospital.name,
                style: GoogleFonts.inter(
                  fontSize: 16, // Reduced from 18
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4), // Reduced from 8
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, // Reduced from 12
                      vertical: 4, // Reduced from 6
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getCategoryColor().withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.hospital.category,
                      style: GoogleFonts.inter(
                        fontSize: 10, // Reduced from 12
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(),
                      ),
                    ),
                  ),
                  if (widget.hospital.accreditation.isNotEmpty) ...[
                    const SizedBox(width: 6), // Reduced from 8
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // Reduced from 8
                        vertical: 3, // Reduced from 4
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 10,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.hospital.accreditation,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        // Compact Distance Badge
        if (distance != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${distance.toStringAsFixed(1)}km',
              style: GoogleFonts.inter(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Reduced from 8
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.location_city_rounded,
              size: 14, // Reduced from 18
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 8), // Reduced from 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location',
                  style: GoogleFonts.inter(
                    fontSize: 10, // Reduced from 12
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                Text(
                  '${widget.hospital.district}, ${widget.hospital.state}',
                  style: GoogleFonts.inter(
                    fontSize: 13, // Reduced from 14
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBedInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoChip(
            icon: Icons.bed_rounded,
            label: 'Total',
            value: widget.hospital.totalBeds.toString(),
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 8), // Reduced from 12
        Expanded(
          child: _buildInfoChip(
            icon: Icons.check_circle_rounded,
            label: 'Available',
            value: widget.hospital.availableBeds.toString(),
            color: widget.hospital.availableBeds > 0
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 8), // Reduced from 12
        Expanded(
          child: _buildInfoChip(
            icon: Icons.hotel_rounded,
            label: 'Private',
            value: widget.hospital.privateWards.toString(),
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialties() {
    final displaySpecialties = widget.hospital.specialties.take(3).toList(); // Reduced from 4
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialties',
          style: GoogleFonts.inter(
            fontSize: 12, // Reduced from 14
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6), // Reduced from 8
        Wrap(
          spacing: 6, // Reduced from 8
          runSpacing: 6, // Reduced from 8
          children: displaySpecialties.map((specialty) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0EA5E9).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                specialty,
                style: GoogleFonts.inter(
                  fontSize: 10, // Reduced from 12
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0C4A6E),
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.hospital.specialties.length > 3) // Updated from 4
          Padding(
            padding: const EdgeInsets.only(top: 4), // Reduced from 8
            child: Text(
              '+${widget.hospital.specialties.length - 3} more',
              style: GoogleFonts.inter(
                fontSize: 10, // Reduced from 12
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Call Button
        if (widget.hospital.telephone.isNotEmpty)
          Expanded(
            child: Container(
              height: 36, // Fixed height to make more compact
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _makePhoneCall(widget.hospital.telephone),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.call_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Call',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (widget.hospital.telephone.isNotEmpty &&
            (widget.hospital.latitude != 0 && widget.hospital.longitude != 0))
          const SizedBox(width: 8),

        // Navigate Button
        if (widget.hospital.latitude != 0 && widget.hospital.longitude != 0)
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF667EEA),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openMaps,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.navigation_rounded,
                        color: Color(0xFF667EEA),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Navigate',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667EEA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Emergency Button
        if (widget.hospital.emergencyNum.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _makePhoneCall(widget.hospital.emergencyNum),
                borderRadius: BorderRadius.circular(10),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10), // Reduced from 14
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color), // Reduced from 18
          const SizedBox(height: 2), // Reduced from 4
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14, // Reduced from 15
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9, // Reduced from 10
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (widget.hospital.category.toLowerCase()) {
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

  IconData _getCategoryIcon() {
    switch (widget.hospital.category.toLowerCase()) {
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      print('Could not launch phone call: $e');
    }
  }

  Future<void> _openMaps() async {
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${widget.hospital.latitude},${widget.hospital.longitude}&travelmode=driving';

    final Uri launchUri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Could not launch maps: $e');
    }
  }
}