import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khair_e_kaseer/screens/volunteer/active_tracking_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PickupDetailsScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const PickupDetailsScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<PickupDetailsScreen> createState() => _PickupDetailsScreenState();
}

class _PickupDetailsScreenState extends State<PickupDetailsScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  /// Helper method to save targeted single-user notifications into Firestore
  Future<void> _saveNotificationToFirestore({
    required String title,
    required String body,
    required String targetRole,
    required String recipientId,
    required String orderId,
  }) async {
    try {
      if (recipientId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(recipientId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'targetRole': targetRole,
          'recipientId': recipientId,
          'orderId': orderId,
          'sopCategory': 'Order Status',
          'type': 'Order Status',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  Future<void> _acceptAndProceed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Fetch Real Volunteer Profile
      String riderName = 'Volunteer';
      String riderVehicle = 'Bike';

      try {
        DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (volunteerDoc.exists && volunteerDoc.data() != null) {
          Map<String, dynamic> vData =
          volunteerDoc.data() as Map<String, dynamic>;
          riderName = vData['name'] ?? vData['fullName'] ?? 'Volunteer';
          riderVehicle = vData['vehicleType'] ?? vData['vehicle'] ?? 'Bike';
        }
      } catch (e) {
        debugPrint("Error fetching volunteer profile: $e");
      }

      // 1. Update Order Status with REAL volunteer details
      await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.orderId)
          .update({
        'status': 'Accepted',
        'volunteerId': user.uid,
        'riderName': riderName,
        'riderVehicle': riderVehicle,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 2. Extract user IDs and food details for notification dispatches
      String donorId = widget.orderData['donorId'] ?? '';
      String beneficiaryId = widget.orderData['beneficiaryId'] ??
          widget.orderData['claimedBy'] ??
          '';
      String foodTitle = widget.orderData['foodName'] ??
          widget.orderData['foodTitle'] ??
          "Food Item";

      // 3. Notify Donor in Firestore
      if (donorId.isNotEmpty) {
        await _saveNotificationToFirestore(
          title: "Rider Assigned!",
          body:
          "$riderName has accepted the order for '$foodTitle' and is heading to your location for pickup.",
          targetRole: "Donor",
          recipientId: donorId,
          orderId: widget.orderId,
        );
      }

      // 4. Notify Beneficiary in Firestore
      if (beneficiaryId.isNotEmpty) {
        await _saveNotificationToFirestore(
          title: "Rider On the Way!",
          body:
          "$riderName has accepted your request for '$foodTitle' and will be delivering it soon.",
          targetRole: "Beneficiary",
          recipientId: beneficiaryId,
          orderId: widget.orderId,
        );
      }

      // 5. Send FCM Push Notifications if user tokens exist
      String? donorFcmToken = widget.orderData['donorFcmToken'];
      if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: donorFcmToken,
          title: "Rider Assigned!",
          body: "$riderName is on the way to pick up '$foodTitle'.",
        );
      }

      String? beneficiaryFcmToken = widget.orderData['beneficiaryFcmToken'] ??
          widget.orderData['fcmToken'];
      if (beneficiaryFcmToken != null && beneficiaryFcmToken.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: beneficiaryFcmToken,
          title: "Delivery Update",
          body:
          "$riderName has accepted your order and is picking up '$foodTitle'.",
        );
      }

      if (mounted) {
        String donorName = widget.orderData['donorName'] ?? "Donor Location";
        String pickupAddress = widget.orderData['pickupAddress'] ??
            widget.orderData['address'] ??
            "Pickup Point";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveTrackingScreen(
              stepTitle: "Step 1 : Pickup",
              destinationName: donorName,
              destinationAddress: pickupAddress,
              isPickupMode: true,
              orderId: widget.orderId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error accepting order: $e")),
        );
      }
    }
  }

  Future<void> _openMap() async {
    String address = widget.orderData['pickupAddress'] ??
        widget.orderData['address'] ??
        "Islamabad";
    final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.orderData;

    String donorName = data['donorName'] ?? "Donor";
    String pickupAddress =
        data['pickupAddress'] ?? data['address'] ?? "Pickup Address Not Provided";
    String beneficiaryName =
        data['beneficiaryName'] ?? data['claimedByName'] ?? "Beneficiary";
    String deliveryAddress = data['deliveryAddress'] ??
        data['receiverAddress'] ??
        "Delivery Address Not Provided";

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Request Details",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront,
                        color: primaryGreen, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['foodName'] ?? data['foodTitle'] ?? "Food Item",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Donor: $donorName",
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.near_me, color: Colors.white),
                    onPressed: _openMap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Route Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildRouteStep(
                      Icons.location_on, primaryGreen, "Pickup From ($donorName)", pickupAddress),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          width: 2, height: 25, color: Colors.grey.shade300),
                    ),
                  ),
                  _buildRouteStep(Icons.flag, Colors.orange, "Deliver To ($beneficiaryName)",
                      deliveryAddress),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Food Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildInfoRow("Food Item", data['foodName'] ?? data['foodTitle'] ?? "N/A"),
                  const Divider(),
                  _buildInfoRow("Quantity", "${data['portionsClaimed']} Packs"),
                  const Divider(),
                  _buildInfoRow("Status", data['status'] ?? "Pending"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: Colors.orange.shade800),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Note: Pickup must be completed within 20-30 minutes for food safety.",
                      style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _acceptAndProceed,
                child: const Text("PROCEED TO PICKUP",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStep(
      IconData icon, Color color, String label, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(address,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}