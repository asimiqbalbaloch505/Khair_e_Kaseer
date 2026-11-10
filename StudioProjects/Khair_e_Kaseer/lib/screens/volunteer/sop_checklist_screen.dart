import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/volunteer/active_tracking_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class SOPChecklistScreen extends StatefulWidget {
  final String orderId;

  const SOPChecklistScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<SOPChecklistScreen> createState() => _SOPChecklistScreenState();
}

class _SOPChecklistScreenState extends State<SOPChecklistScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  bool isFresh = false;
  bool isSealed = false;
  bool isClean = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Safety Verification", style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quality Check", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Please verify the following before picking up the food:",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            _buildCheckboxTile("Food is fresh (within 4-6 hours)", isFresh, (val) {
              setState(() => isFresh = val!);
            }),
            _buildCheckboxTile("Containers are properly sealed", isSealed, (val) {
              setState(() => isSealed = val!);
            }),
            _buildCheckboxTile("Hygienic handling maintained", isClean, (val) {
              setState(() => isClean = val!);
            }),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isFresh && isSealed && isClean) ? primaryGreen : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (isFresh && isSealed && isClean)
                    ? () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('Orders')
                        .doc(widget.orderId)
                        .update({
                      'status': 'In Transit',
                    });

                    // Fetch order details to notify the beneficiary
                    DocumentSnapshot orderDoc = await FirebaseFirestore.instance
                        .collection('Orders')
                        .doc(widget.orderId)
                        .get();

                    if (orderDoc.exists) {
                      var data = orderDoc.data() as Map<String, dynamic>?;
                      String? beneficiaryFcmToken =
                          data?['beneficiaryFcmToken'] ?? data?['fcmToken'];

                      if (beneficiaryFcmToken != null && beneficiaryFcmToken.isNotEmpty) {
                        await FCMClientService.sendNotificationToUserToken(
                          targetFcmToken: beneficiaryFcmToken,
                          title: "Order On The Way!",
                          body: "The volunteer has verified quality check and picked up your food delivery.",
                        );
                      }
                    }

                    if (!mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActiveTrackingScreen(
                          stepTitle: "Step 2: Delivery",
                          destinationName: "Receiver Location",
                          destinationAddress: "Delivery Point",
                          isPickupMode: false,
                          orderId: widget.orderId,
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error updating status: $e")),
                    );
                  }
                }
                    : null,
                child: const Text(
                  "CONFIRM & PICKUP",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile(String title, bool value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? primaryGreen : Colors.grey.shade300),
      ),
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        value: value,
        activeColor: primaryGreen,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}