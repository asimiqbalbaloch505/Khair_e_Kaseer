import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class DonorHandoverVerifyScreen extends StatefulWidget {
  final String correctOrderId;
  const DonorHandoverVerifyScreen({super.key, required this.correctOrderId});

  @override
  State<DonorHandoverVerifyScreen> createState() => _DonorHandoverVerifyScreenState();
}

class _DonorHandoverVerifyScreenState extends State<DonorHandoverVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  final Color primaryGreen = const Color(0xFF347A5C);
  bool _isLoading = false;

  Future<void> _verifyAndComplete() async {
    String enteredOtp = _otpController.text.trim();

    if (enteredOtp.isEmpty || enteredOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 4-digit OTP.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot? docToUpdate;
      String actualOtp = "";
      bool isOrdersCollection = false;

      // 1. Try checking inside 'Orders' collection first
      DocumentSnapshot orderDoc = await FirebaseFirestore.instance
          .collection('Orders')
          .doc(widget.correctOrderId)
          .get();

      if (orderDoc.exists) {
        docToUpdate = orderDoc;
        var data = orderDoc.data() as Map<String, dynamic>;

        // FIX: Check pickupOtp FIRST before fallback
        actualOtp = (data['pickupOtp'] ?? data['otp'] ?? data['claimOtp'] ?? "").toString();
        isOrdersCollection = true;
      } else {
        // 2. Fallback to 'FoodDonations' / 'Donations' collection (NGO Bulk claims)
        DocumentSnapshot foodDoc = await FirebaseFirestore.instance
            .collection('FoodDonations')
            .doc(widget.correctOrderId)
            .get();

        if (foodDoc.exists) {
          docToUpdate = foodDoc;
          var data = foodDoc.data() as Map<String, dynamic>;
          actualOtp = (data['pickupOtp'] ?? data['otp'] ?? data['claimOtp'] ?? "").toString();
        } else {
          // 3. Fallback check inside 'Donations' collection directly
          DocumentSnapshot donDoc = await FirebaseFirestore.instance
              .collection('Donations')
              .doc(widget.correctOrderId)
              .get();

          if (donDoc.exists) {
            docToUpdate = donDoc;
            var data = donDoc.data() as Map<String, dynamic>;
            actualOtp = (data['pickupOtp'] ?? data['otp'] ?? data['claimOtp'] ?? "").toString();
          }
        }
      }

      if (docToUpdate == null || !docToUpdate.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order/Claim record not found in database.")),
        );
        return;
      }

      // Check entered OTP against the actual pickup OTP
      if (enteredOtp == actualOtp) {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        Map<String, dynamic> updatePayload = {
          'status': 'Picked',
          'handedOverAt': FieldValue.serverTimestamp(),
        };

        if (isOrdersCollection) {
          batch.update(
            FirebaseFirestore.instance.collection('Orders').doc(widget.correctOrderId),
            updatePayload,
          );
        } else {
          // Update both FoodDonations and Donations for consistency
          DocumentReference foodRef = FirebaseFirestore.instance.collection('FoodDonations').doc(widget.correctOrderId);
          DocumentReference donRef = FirebaseFirestore.instance.collection('Donations').doc(widget.correctOrderId);

          batch.set(foodRef, updatePayload, SetOptions(merge: true));
          batch.set(donRef, updatePayload, SetOptions(merge: true));
        }

        await batch.commit();

        // Extract token and send notification to receiver
        var docData = docToUpdate.data() as Map<String, dynamic>?;
        String? receiverFcmToken = docData?['beneficiaryFcmToken'] ??
            docData?['claimerFcmToken'] ??
            docData?['volunteerFcmToken'] ??
            docData?['fcmToken'];

        if (receiverFcmToken != null && receiverFcmToken.isNotEmpty) {
          FCMClientService.sendNotificationToUserToken(
            targetFcmToken: receiverFcmToken,
            title: "Handover Verified",
            body: "The donor has verified the pickup OTP and handed over your food item!",
          );
        }

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 20),
                const Text(
                  "Verification Successful!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                const Text(
                  "The pickup handover has been recorded successfully.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close Dialog
                    Navigator.of(context).pop(); // Close Verify Screen
                  },
                  child: const Text("Done", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Pickup OTP! Please check the 4-digit OTP on the Volunteer's screen."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during verification: $e")),
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
        title: const Text("Secure Pickup Handover"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Icon(Icons.verified_user_outlined, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              "Pickup Handover OTP",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Enter the 4-digit Pickup OTP shown on the Volunteer's or NGO's screen.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Enter Pickup OTP",
                hintText: "• • • •",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.vpn_key),
                filled: true,
                fillColor: Colors.white,
                counterText: "",
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _verifyAndComplete,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "VERIFY & CONFIRM PICKUP",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}