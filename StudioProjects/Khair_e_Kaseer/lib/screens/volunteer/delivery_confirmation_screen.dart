import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/volunteer/volunteer_dashboard_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  final String? orderId;

  const DeliveryConfirmationScreen({super.key, this.orderId});

  @override
  State<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _sendCompletionNotifications(widget.orderId!);
    }
  }

  /// Helper method to save single-user notification entry into Firestore
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
          'sopCategory': 'Delivery Complete',
          'type': 'Delivery Complete',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  /// Sends targeted completion notifications to both Donor and Beneficiary
  Future<void> _sendCompletionNotifications(String orderId) async {
    try {
      DocumentSnapshot orderSnap = await FirebaseFirestore.instance
          .collection('Orders')
          .doc(orderId)
          .get();

      if (!orderSnap.exists) return;

      Map<String, dynamic> orderData = orderSnap.data() as Map<String, dynamic>;

      String donorId = orderData['donorId'] ?? '';
      String beneficiaryId = orderData['beneficiaryId'] ?? orderData['claimedBy'] ?? '';
      String foodTitle = orderData['foodTitle'] ?? orderData['foodName'] ?? "Donation";

      // 1. Notify Donor in Firestore
      if (donorId.isNotEmpty) {
        await _saveNotificationToFirestore(
          title: "Donation Delivered!",
          body: "Your food donation '$foodTitle' has been successfully delivered by the volunteer.",
          targetRole: "Donor",
          recipientId: donorId,
          orderId: orderId,
        );
      }

      // 2. Notify Beneficiary in Firestore
      if (beneficiaryId.isNotEmpty) {
        await _saveNotificationToFirestore(
          title: "Order Delivered!",
          body: "Your order for '$foodTitle' has been successfully delivered. Enjoy your meal!",
          targetRole: "Beneficiary",
          recipientId: beneficiaryId,
          orderId: orderId,
        );
      }

      // 3. Send FCM Push Notification to Donor
      String? donorFcmToken = orderData['donorFcmToken'];
      if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: donorFcmToken,
          title: "Donation Delivered!",
          body: "Your food donation '$foodTitle' has been successfully delivered.",
        );
      }

      // 4. Send FCM Push Notification to Beneficiary
      String? beneficiaryFcmToken = orderData['beneficiaryFcmToken'] ?? orderData['fcmToken'];
      if (beneficiaryFcmToken != null && beneficiaryFcmToken.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: beneficiaryFcmToken,
          title: "Order Delivered!",
          body: "Your food order '$foodTitle' has been delivered.",
        );
      }
    } catch (e) {
      debugPrint("Error sending completion notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: primaryGreen, size: 100),
              ),

              const SizedBox(height: 30),

              const Text(
                "Delivery Successful!",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              const Text(
                "JazakAllah! Your contribution has helped reduce food waste and feed someone in need.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),

              const SizedBox(height: 50),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.amber),
                    SizedBox(width: 10),
                    Text(
                      "You earned 50 Impact Points!",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const VolunteerDashboard()),
                          (route) => false,
                    );
                  },
                  child: const Text(
                    "BACK TO DASHBOARD",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}