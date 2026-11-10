import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khair_e_kaseer/widgets/tracking/live_map_tracking_widget.dart';
import 'package:khair_e_kaseer/widgets/tracking/order_status_stepper.dart';
import 'package:khair_e_kaseer/widgets/tracking/otp_handover_dialog.dart';

class DonorOrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const DonorOrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DonorOrderTrackingScreen> createState() => _DonorOrderTrackingScreenState();
}

class _DonorOrderTrackingScreenState extends State<DonorOrderTrackingScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);

  void _openHandoverOtpDialog({
    required String expectedOtp,
    required String recipientName,
    required String recipientRole,
  }) {
    showDialog(
      context: context,
      builder: (context) => OtpHandoverDialog(
        orderId: widget.orderId,
        expectedOtp: expectedOtp,
        recipientName: recipientName,
        recipientRole: recipientRole,
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint("Error launching phone call: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Donor Live Tracking",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          Map<String, dynamic>? orderData;
          if (snapshot.hasData && snapshot.data!.exists) {
            orderData = snapshot.data!.data() as Map<String, dynamic>?;
          }

          if (orderData == null) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('Donations').doc(widget.orderId).snapshots(),
              builder: (context, altSnap) {
                if (altSnap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                if (!altSnap.hasData || !altSnap.data!.exists) {
                  return const Center(child: Text("Tracking data unavailable for this order."));
                }

                Map<String, dynamic> altData = altSnap.data!.data() as Map<String, dynamic>;
                return _buildTrackingBody(altData);
              },
            );
          }

          return _buildTrackingBody(orderData);
        },
      ),
    );
  }

  Widget _buildTrackingBody(Map<String, dynamic> data) {
    String status = (data['status'] ?? data['orderStatus'] ?? 'Pending').toString();
    String deliveryType = (data['deliveryType'] ?? data['fulfillmentMethod'] ?? 'rider_delivery').toString();
    bool isSelfPickup = deliveryType.toLowerCase().contains('pickup') || deliveryType.toLowerCase().contains('self');

    String foodTitle = data['foodName'] ?? data['foodTitle'] ?? "Donated Food";
    String recipientName = data['beneficiaryName'] ?? data['claimedBy'] ?? "Beneficiary";
    String recipientPhone = data['beneficiaryPhone'] ?? '';

    String riderName = data['riderName'] ?? "Volunteer Rider";
    String riderVehicle = data['riderVehicle'] ?? "Bike";
    String riderPhone = data['riderPhone'] ?? '';

    String expectedOtp = data['pickupOtp'] ?? data['otp'] ?? data['claimOtp'] ?? "000000";

    bool isRiderAssigned = data['volunteerId'] != null || data['riderName'] != null;
    bool isPickedUp = status.toLowerCase() == 'picked' || status.toLowerCase() == 'picked_up' || status.toLowerCase() == 'completed' || status.toLowerCase() == 'delivered';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Overview Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryGreen.withOpacity(0.12),
                  child: Icon(Icons.fastfood_outlined, color: primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        "Fulfillment: ${isSelfPickup ? 'Self-Pickup' : 'Rider Delivery'}",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPickedUp ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPickedUp ? Colors.green.shade300 : Colors.amber.shade300),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPickedUp ? Colors.green.shade800 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Live Map View
          LiveMapTrackingWidget(
            pickupLocation: data['pickupLocation'] as Map<String, dynamic>?,
            liveLocation: data['riderLocation'] as Map<String, dynamic>?,
            destinationLocation: data['beneficiaryLocation'] as Map<String, dynamic>?,
            activeRole: isSelfPickup ? 'beneficiary' : 'rider',
            statusText: status,
            etaText: "~10-15 Mins",
            distanceText: "1.5 km away",
          ),

          const SizedBox(height: 16),

          // Progress Stepper
          OrderStatusStepper(
            orderStatus: status,
            deliveryType: deliveryType,
          ),

          const SizedBox(height: 16),

          // Contact & Active Agent Card
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelfPickup ? "Beneficiary Contact" : "Assigned Volunteer Rider",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: primaryGreen.withOpacity(0.12),
                      child: Icon(
                        isSelfPickup ? Icons.person_outline : Icons.directions_bike_outlined,
                        color: primaryGreen,
                      ),
                    ),
                    title: Text(
                      isSelfPickup ? recipientName : (isRiderAssigned ? riderName : "Waiting for Volunteer..."),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isSelfPickup
                          ? "Beneficiary Collecting Food"
                          : "Vehicle: $riderVehicle | Rating: 4.9 ★",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () => _makePhoneCall(isSelfPickup ? recipientPhone : riderPhone),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Handover OTP Action Button
          if (!isPickedUp)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.pin_outlined),
                label: const Text(
                  "VERIFY HANDOVER OTP",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openHandoverOtpDialog(
                  expectedOtp: expectedOtp,
                  recipientName: isSelfPickup ? recipientName : riderName,
                  recipientRole: isSelfPickup ? 'beneficiary' : 'rider',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
