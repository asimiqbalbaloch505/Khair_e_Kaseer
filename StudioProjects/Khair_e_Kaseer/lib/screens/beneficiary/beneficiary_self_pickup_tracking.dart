import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BeneficiarySelfPickupTrackingScreen extends StatefulWidget {
  final String orderDocId;

  const BeneficiarySelfPickupTrackingScreen({
    super.key,
    required this.orderDocId,
  });

  @override
  State<BeneficiarySelfPickupTrackingScreen> createState() => _BeneficiarySelfPickupTrackingScreenState();
}

class _BeneficiarySelfPickupTrackingScreenState extends State<BeneficiarySelfPickupTrackingScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  bool _dialogShown = false;

  void _showCompletionDialog() {
    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Color(0xFF347A5C), size: 60),
            const SizedBox(height: 10),
            const Text(
              "Enjoy Your Meal!",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        content: const Text(
          "Food handover has been verified and completed successfully.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
  Future<void> _cancelOrder(Map<String, dynamic> orderData) async {
    try {
      String donationId = orderData['donationId'] ?? widget.orderDocId;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference donationRef = FirebaseFirestore.instance.collection('Donations').doc(donationId);
        DocumentReference orderRef = FirebaseFirestore.instance.collection('Orders').doc(widget.orderDocId);

        // --- ALL READS FIRST ---
        DocumentSnapshot donationSnap = await transaction.get(donationRef);
        DocumentSnapshot orderSnap = await transaction.get(orderRef);

        // --- ALL WRITES AFTER READS ---
        if (donationSnap.exists && donationSnap.data() != null) {
          Map<String, dynamic> donationData = donationSnap.data() as Map<String, dynamic>;

          dynamic rawPortions = orderData['portionsClaimed'] ?? orderData['quantityDescription'] ?? 1;
          int portionsToReturn = 0;
          if (rawPortions is int) {
            portionsToReturn = rawPortions;
          } else if (rawPortions is String) {
            portionsToReturn = int.tryParse(rawPortions.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          }

          dynamic rawRemaining = donationData['remainingPortions'] ?? donationData['portions'] ?? donationData['totalPortions'] ?? 0;
          int remainingVal = 0;
          if (rawRemaining is int) {
            remainingVal = rawRemaining;
          } else if (rawRemaining is String) {
            remainingVal = int.tryParse(rawRemaining) ?? 0;
          }

          transaction.update(donationRef, {
            'remainingPortions': remainingVal + portionsToReturn,
            'status': 'Available',
            'claimedBy': FieldValue.delete(),
            'beneficiaryId': FieldValue.delete(),
            'claimedByRole': FieldValue.delete(),
            'fulfillmentMethod': FieldValue.delete(),
            'deliveryType': FieldValue.delete(),
            'otp': FieldValue.delete(),
            'claimOtp': FieldValue.delete(),
            'orderDocId': FieldValue.delete(),
          });
        }

        if (orderSnap.exists) {
          transaction.delete(orderRef);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order cancelled and restored to available donations.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text('Pickup Tracking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Orders').doc(widget.orderDocId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryGreen));
          }

          Map<String, dynamic>? data;
          if (snapshot.hasData && snapshot.data!.exists) {
            data = snapshot.data!.data() as Map<String, dynamic>?;
          }

          if (data == null) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('Donations').doc(widget.orderDocId).snapshots(),
              builder: (context, altSnapshot) {
                if (altSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryGreen));
                }

                if (!altSnapshot.hasData || !altSnapshot.data!.exists) {
                  return const Center(child: Text("Order details not found."));
                }
                var altData = altSnapshot.data!.data() as Map<String, dynamic>;
                return _buildPickupUI(altData);
              },
            );
          }

          return _buildPickupUI(data);
        },
      ),
    );
  }

  Widget _buildPickupUI(Map<String, dynamic> data) {
    String status = (data['status'] ?? '').toString().trim().toLowerCase();
    String otp = data['otp'] ?? data['claimOtp'] ?? '----';
    String displayId = (data['orderId'] ?? widget.orderDocId);
    if (displayId.length >= 6) {
      displayId = "KF-${displayId.substring(displayId.length - 4).toUpperCase()}";
    }

    if (status == 'picked' || status == 'handed over' || status == 'completed' || status == 'delivered') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionDialog();
      });
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            color: const Color(0xFFEFEFEF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text("Google Maps Navigation Visual", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      (status == 'picked' || status == 'handed over' || status == 'completed')
                          ? "Food Handover Verified!"
                          : "Food Handover Code",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FDF9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryGreen.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text("ORDER TRACKING ID", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(displayId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const Divider(height: 25),
                      Text("SHARE 4-DIGIT OTP FOR HANDOVER", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Text(
                        otp,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                          letterSpacing: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.qr_code_2, color: Colors.white),
                    label: const Text("PICKUP IN PROGRESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Provide the 4-digit OTP code to the donor during handover.")),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                if (status != 'picked' && status != 'completed' && status != 'handed over')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _cancelOrder(data),
                      child: const Text("Cancel Pickup Request", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}