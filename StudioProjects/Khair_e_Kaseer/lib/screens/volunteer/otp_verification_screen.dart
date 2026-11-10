import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/volunteer/delivery_confirmation_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String orderId;

  const OTPVerificationScreen({super.key, required this.orderId});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final Color primaryGreen = const Color(0xFF347A5C);
  bool _isLoading = false;

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
          'sopCategory': 'OTP Verification',
          'type': 'OTP Verification',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  Future<void> _verifyOTP() async {
    String enteredOTP = _otpController.text.trim();

    if (enteredOTP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the Delivery OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot orderDoc = await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.orderId)
          .get();

      if (orderDoc.exists) {
        var data = orderDoc.data() as Map<String, dynamic>?;

        // VERIFY AGAINST DELIVERY OTP
        String correctOTP = (data?['deliveryOtp'] ?? data?['otp'] ?? '').toString();

        if (enteredOTP == correctOTP) {
          await FirebaseFirestore.instance
              .collection('Orders')
              .doc(widget.orderId)
              .update({
            'status': 'Completed',
            'deliveredAt': FieldValue.serverTimestamp(),
          });

          String donorId = data?['donorId'] ?? '';
          String beneficiaryId = data?['beneficiaryId'] ?? data?['claimedBy'] ?? '';
          String foodTitle = data?['foodTitle'] ?? data?['foodName'] ?? 'Donation';

          // ===================================================
          // FIRESTORE NOTIFICATIONS (App Alerts Feed)
          // ===================================================
          if (donorId.isNotEmpty) {
            await _saveNotificationToFirestore(
              title: "Donation Delivered!",
              body: "Your food donation '$foodTitle' was successfully handed over to the beneficiary. JazakAllah!",
              targetRole: "Donor",
              recipientId: donorId,
              orderId: widget.orderId,
            );
          }

          if (beneficiaryId.isNotEmpty) {
            await _saveNotificationToFirestore(
              title: "Order Completed",
              body: "Your order for '$foodTitle' is complete. Enjoy your meal!",
              targetRole: "Beneficiary",
              recipientId: beneficiaryId,
              orderId: widget.orderId,
            );
          }

          // ===================================================
          // FCM PUSH NOTIFICATIONS
          // ===================================================
          String? donorFcmToken = data?['donorFcmToken'];
          String? beneficiaryFcmToken = data?['beneficiaryFcmToken'] ?? data?['fcmToken'];

          // Notify Donor
          if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
            await FCMClientService.sendNotificationToUserToken(
              targetFcmToken: donorFcmToken,
              title: "Donation Delivered!",
              body: "Your food donation has been successfully handed over to the beneficiary. JazakAllah for your contribution!",
            );
          }

          // Notify Beneficiary
          if (beneficiaryFcmToken != null && beneficiaryFcmToken.isNotEmpty) {
            await FCMClientService.sendNotificationToUserToken(
              targetFcmToken: beneficiaryFcmToken,
              title: "Order Completed",
              body: "Your food delivery is complete. Enjoy your meal!",
            );
          }

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryConfirmationScreen(orderId: widget.orderId),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid Delivery OTP! Please check with the receiver.")),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        title: const Text("Verify Delivery"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              "Enter Delivery OTP",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Ask the beneficiary for their 4-digit Delivery OTP",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "Enter 4-digit OTP",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "VERIFY & COMPLETE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}