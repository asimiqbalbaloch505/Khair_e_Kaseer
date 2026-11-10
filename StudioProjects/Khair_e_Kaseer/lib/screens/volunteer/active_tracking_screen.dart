import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/volunteer/otp_verification_screen.dart';
import 'package:khair_e_kaseer/screens/volunteer/sop_checklist_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';
import 'package:khair_e_kaseer/screens/volunteer/otp_verification_screen.dart';

class ActiveTrackingScreen extends StatelessWidget {
  final String stepTitle;
  final String destinationName;
  final String destinationAddress;
  final bool isPickupMode;
  final String orderId;

  const ActiveTrackingScreen({
    super.key,
    required this.stepTitle,
    required this.destinationName,
    required this.destinationAddress,
    required this.isPickupMode,
    required this.orderId,
  });

  /// Helper method to save single-user notification entry in Firestore
  Future<void> _saveNotificationToFirestore({
    required String title,
    required String body,
    required String targetRole,
    String? recipientId,
    String? orderId,
  }) async {
    try {
      if (recipientId != null && recipientId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(recipientId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'targetRole': targetRole,
          'recipientId': recipientId,
          'orderId': orderId ?? '',
          'sopCategory': 'Delivery Update',
          'type': 'Delivery Update',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF347A5C);

    String displayId = orderId.length >= 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Active Delivery", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('Orders').doc(orderId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text("Order not found or deleted."));
            }

            var orderData = snapshot.data!.data() as Map<String, dynamic>;
            String currentStatus = orderData['status'] ?? 'Accepted';

            // DUAL OTP SUPPORT
            String pickupOtp = orderData['pickupOtp'] ?? orderData['otp'] ?? "----";
            String deliveryOtp = orderData['deliveryOtp'] ?? orderData['otp'] ?? "----";

            bool isHandoverPending = (currentStatus == 'Accepted');
            bool showPickupUI = isPickupMode && isHandoverPending;

            String activeDestinationName = showPickupUI
                ? (orderData['donorName'] ?? destinationName)
                : (orderData['beneficiaryName'] ?? destinationName);

            String activeDestinationAddress = showPickupUI
                ? (orderData['pickupAddress'] ?? destinationAddress)
                : (orderData['deliveryAddress'] ?? destinationAddress);

            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 60, color: Colors.grey),
                          Text("Live Map Integration", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 15),

                          Text(
                            showPickupUI ? "Pickup Food" : "Deliver Food",
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            showPickupUI
                                ? "Show Pickup OTP to Donor"
                                : "Proceeding to Beneficiary destination",
                            style: TextStyle(
                              color: showPickupUI
                                  ? Colors.orange.shade800
                                  : primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Divider(height: 30),

                          Row(
                            children: [
                              Icon(
                                showPickupUI
                                    ? Icons.restaurant
                                    : Icons.person_pin_circle,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      showPickupUI ? "Pickup From" : "Deliver To",
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                    Text(
                                      activeDestinationName,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      activeDestinationAddress,
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),

                          const SizedBox(height: 25),

                          if (showPickupUI)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBFBF4),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: primaryGreen, width: 2),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    "STEP 1: SHOW ORDER ID",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    displayId,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 4),
                                  ),
                                  const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Divider()),
                                  const Text(
                                    "STEP 2: SHOW PICKUP OTP TO DONOR",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    pickupOtp,
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: primaryGreen,
                                        letterSpacing: 8),
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
                                backgroundColor: isHandoverPending
                                    ? Colors.grey.shade400
                                    : primaryGreen,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              onPressed: () async {
                                if (currentStatus == 'Accepted') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Pickup not verified yet. Please ask Donor to enter OTP."),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                } else if (currentStatus == 'Picked') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SOPChecklistScreen(orderId: orderId),
                                    ),
                                  );
                                } else {
                                  // Volunteer clicks "I HAVE ARRIVED" at delivery point
                                  String beneficiaryId =
                                      orderData['beneficiaryId'] ?? orderData['claimedBy'] ?? '';

                                  // 1. Save targeted Firestore notification for Beneficiary
                                  if (beneficiaryId.isNotEmpty) {
                                    await _saveNotificationToFirestore(
                                      title: "Volunteer Arrived!",
                                      body: "Your volunteer has arrived with your food delivery. Please share your Delivery OTP with the rider.",
                                      targetRole: "Beneficiary",
                                      recipientId: beneficiaryId,
                                      orderId: orderId,
                                    );
                                  }

                                  // 2. Direct FCM Push notification
                                  String? beneficiaryFcmToken =
                                      orderData['beneficiaryFcmToken'] ?? orderData['fcmToken'];
                                  if (beneficiaryFcmToken != null &&
                                      beneficiaryFcmToken.isNotEmpty) {
                                    await FCMClientService.sendNotificationToUserToken(
                                      targetFcmToken: beneficiaryFcmToken,
                                      title: "Volunteer Arrived!",
                                      body: "Your volunteer has arrived with your food delivery. Please share your Delivery OTP with the rider.",
                                    );
                                  }

                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OTPVerificationScreen(orderId: orderId),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                currentStatus == 'Accepted'
                                    ? "WAITING FOR DONOR VERIFICATION..."
                                    : (currentStatus == 'Picked'
                                    ? "PROCEED TO QUALITY CHECK"
                                    : "I HAVE ARRIVED"),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
    );
  }
}