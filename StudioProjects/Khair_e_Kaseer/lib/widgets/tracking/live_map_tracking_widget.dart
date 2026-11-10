import 'package:flutter/material.dart';

class LiveMapTrackingWidget extends StatelessWidget {
  final Map<String, dynamic>? pickupLocation;
  final Map<String, dynamic>? liveLocation;
  final Map<String, dynamic>? destinationLocation;
  final String activeRole; // 'rider' or 'beneficiary'
  final String statusText;
  final String etaText;
  final String distanceText;

  const LiveMapTrackingWidget({
    super.key,
    this.pickupLocation,
    this.liveLocation,
    this.destinationLocation,
    required this.activeRole,
    required this.statusText,
    required this.etaText,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF347A5C);

    bool hasLiveLocation = liveLocation != null &&
        liveLocation!['latitude'] != null &&
        liveLocation!['longitude'] != null;

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          // Visual Map Grid Canvas Simulation
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: MapGridPainter(
                  gridColor: primaryGreen.withOpacity(0.08),
                  lineColor: primaryGreen.withOpacity(0.4),
                  hasLiveLocation: hasLiveLocation,
                ),
              ),
            ),
          ),

          // Top Header: Live Status Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hasLiveLocation ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasLiveLocation ? "LIVE GPS TRACKING" : "ESTIMATED ROUTE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasLiveLocation ? primaryGreen : Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Pins Overlay
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pickup Location Pin
                  _buildMapPin(
                    title: "Donor Spot",
                    icon: Icons.storefront_outlined,
                    color: primaryGreen,
                  ),

                  // Moving Live Location Pin (Rider / Beneficiary)
                  _buildMapPin(
                    title: activeRole == 'rider' ? "Rider" : "Beneficiary",
                    icon: activeRole == 'rider' ? Icons.directions_bike : Icons.directions_walk,
                    color: Colors.blue.shade700,
                    isPulse: true,
                  ),

                  // Destination Pin
                  _buildMapPin(
                    title: "Destination",
                    icon: Icons.location_on_outlined,
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar: Distance & ETA Chips
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route_outlined, size: 16, color: primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        distanceText.isNotEmpty ? distanceText : "1.8 km away",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        etaText.isNotEmpty ? "ETA: $etaText" : "ETA: ~12 Mins",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin({
    required String title,
    required IconData icon,
    required Color color,
    bool isPulse = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isPulse ? 0.4 : 0.2),
                blurRadius: isPulse ? 10 : 4,
                spreadRadius: isPulse ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}

class MapGridPainter extends CustomPainter {
  final Color gridColor;
  final Color lineColor;
  final bool hasLiveLocation;

  MapGridPainter({
    required this.gridColor,
    required this.lineColor,
    required this.hasLiveLocation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    double step = 20;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Connective Route Line
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    Path routePath = Path();
    routePath.moveTo(40, size.height / 2);
    routePath.quadraticBezierTo(size.width / 2, size.height / 3, size.width - 40, size.height / 2);

    canvas.drawPath(routePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) {
    return oldDelegate.hasLiveLocation != hasLiveLocation;
  }
}
