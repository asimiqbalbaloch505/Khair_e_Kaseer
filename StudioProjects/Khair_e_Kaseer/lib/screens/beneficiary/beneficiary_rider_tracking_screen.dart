import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_self_pickup_tracking.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class BeneficiaryRiderTrackingScreen extends StatefulWidget {
  final String orderDocId;
  const BeneficiaryRiderTrackingScreen({super.key, required this.orderDocId});

  @override
  State<BeneficiaryRiderTrackingScreen> createState() => _BeneficiaryRiderTrackingScreenState();
}

class _BeneficiaryRiderTrackingScreenState extends State<BeneficiaryRiderTrackingScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);

  /// Helper method to write single-user or topic notification entries into Firestore
  Future<void> _saveNotificationToFirestore({
    required String title,
    required String body,
    required String targetRole,
    String? recipientId,
    String? orderId,
    String? foodId,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Notifications').add({
        'title': title,
        'body': body,
        'targetRole': targetRole,
        'recipientId': recipientId,
        'orderId': orderId,
        'foodId': foodId,
        'createdAt': Timestamp.now(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint("Error saving notification to Firestore: $e");
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> orderData) async {
    // Restrict NGO order cancellation from rider screen
    String role = (orderData['claimedByRole'] ?? '').toString().toUpperCase();
    if (role == 'NGO') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("NGO bulk orders cannot be cancelled directly. Please contact support/donor."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      String donationId = orderData['donationId'] ?? widget.orderDocId;
      String donorId = orderData['donorId'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference donationRef = FirebaseFirestore.instance
            .collection('Donations')
            .doc(donationId);

        DocumentSnapshot donationSnap = await transaction.get(donationRef);

        // Safe type conversion for portion restoration
        if (donationSnap.exists) {
          dynamic rawPortions = orderData['portionsClaimed'];
          int portionsToReturn = 0;

          if (rawPortions is int) {
            portionsToReturn = rawPortions;
          } else if (rawPortions is String) {
            portionsToReturn = int.tryParse(rawPortions.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          }

          dynamic currentRemaining = donationSnap['remainingPortions'] ?? 0;
          int remainingVal = currentRemaining is int ? currentRemaining : 0;

          // Restore state in Donations collection
          transaction.update(donationRef, {
            'remainingPortions': remainingVal + portionsToReturn,
            'status': 'Available',
            'claimedBy': FieldValue.delete(),
            'claimedByRole': FieldValue.delete(),
            'fulfillmentMethod': FieldValue.delete(),
            'deliveryType': FieldValue.delete(),
          });
        }

        // Remove active tracking entry from Orders collection
        transaction.delete(FirebaseFirestore.instance.collection('Orders').doc(widget.orderDocId));
      });

      // Save notification in Firestore for Donor Alerts
      if (donorId.isNotEmpty) {
        await _saveNotificationToFirestore(
          title: "Order Cancelled",
          body: "A delivery claim on your donation was cancelled by the beneficiary. The item is now listed as Available again.",
          targetRole: "Donor",
          recipientId: donorId,
          orderId: widget.orderDocId,
          foodId: donationId,
        );
      }

      // Send FCM push notification to Donor after cancellation transaction succeeds
      String? donorFcmToken = orderData['donorFcmToken'];
      if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
        await FCMClientService.sendNotificationToUserToken(
          targetFcmToken: donorFcmToken,
          title: "Order Cancelled",
          body: "A delivery claim on your donation was cancelled. The item is now listed as Available again.",
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order cancelled successfully.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to cancel order: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _convertToPickup() async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference orderRef = FirebaseFirestore.instance.collection('Orders').doc(widget.orderDocId);
      DocumentReference donationRef = FirebaseFirestore.instance.collection('Donations').doc(widget.orderDocId);

      Map<String, dynamic> updateData = {
        'deliveryType': 'Self Pickup',
        'fulfillmentMethod': 'Self Pickup',
        'status': 'Claimed',
      };

      batch.set(orderRef, updateData, SetOptions(merge: true));
      batch.set(donationRef, updateData, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        // Retrieve order doc details to notify donor about self pickup switch
        DocumentSnapshot orderSnap = await FirebaseFirestore.instance
            .collection('Orders')
            .doc(widget.orderDocId)
            .get();

        if (orderSnap.exists) {
          Map<String, dynamic>? data = orderSnap.data() as Map<String, dynamic>?;
          String? donorFcmToken = data?['donorFcmToken'];
          String donorId = data?['donorId'] ?? '';

          // Save targeted notification in Firestore for Donor Alerts
          if (donorId.isNotEmpty) {
            await _saveNotificationToFirestore(
              title: "Switched to Self Pickup",
              body: "The beneficiary changed their delivery request to Self Pickup and will collect the food directly.",
              targetRole: "Donor",
              recipientId: donorId,
              orderId: widget.orderDocId,
            );
          }

          if (donorFcmToken != null && donorFcmToken.isNotEmpty) {
            await FCMClientService.sendNotificationToUserToken(
              targetFcmToken: donorFcmToken,
              title: "Delivery Method Changed",
              body: "The beneficiary switched this order to Self Pickup and will arrive directly.",
            );
          }
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BeneficiarySelfPickupTrackingScreen(orderDocId: widget.orderDocId),
          ),
        );
      }
    } catch (e) {
      debugPrint("Convert to Pickup Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error switching to pickup: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text("Track Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Orders').doc(widget.orderDocId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<String, dynamic>? orderData;
          if (snapshot.hasData && snapshot.data!.exists) {
            orderData = snapshot.data!.data() as Map<String, dynamic>?;
          }

          // Fallback to Donations stream if no Orders document exists yet
          if (orderData == null) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('Donations').doc(widget.orderDocId).snapshots(),
              builder: (context, altSnapshot) {
                if (altSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!altSnapshot.hasData || !altSnapshot.data!.exists) {
                  return const Center(child: Text("Order tracking details unavailable."));
                }

                var altData = altSnapshot.data!.data() as Map<String, dynamic>;
                return _buildRiderTrackingContent(altData);
              },
            );
          }

          return _buildRiderTrackingContent(orderData);
        },
      ),
    );
  }

  Widget _buildRiderTrackingContent(Map<String, dynamic> orderData) {
    String status = orderData['status'] ?? 'Pending';
    String displayOtp = orderData['otp'] ?? orderData['claimOtp'] ?? "----";
    bool isRiderAssigned = orderData['volunteerId'] != null || orderData['riderId'] != null;
    bool isNgoClaim = (orderData['claimedByRole'] ?? '').toString().toUpperCase() == 'NGO';

    String statusMessage = "Waiting for a Volunteer to accept...";
    Color statusColor = Colors.orange;

    if (isRiderAssigned) {
      if (status == 'Accepted') {
        statusMessage = "Volunteer is arriving at Donor location";
        statusColor = Colors.blue;
      } else if (status == 'Picked') {
        statusMessage = "Volunteer has picked up your food!";
        statusColor = Colors.green;
      } else if (status == 'Completed' || status == 'Delivered') {
        statusMessage = "Food Delivered! Enjoy your meal.";
        statusColor = primaryGreen;
      }
    }

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey.shade100,
            child: const Center(child: Icon(Icons.map, size: 50, color: Colors.grey)),
          ),
        ),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                if (!isRiderAssigned) ...[
                  const Center(child: CircularProgressIndicator(color: Colors.orange)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Only allow cancellation for non-NGO claims
                      if (!isNgoClaim)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancelOrder(orderData),
                            child: const Text("Cancel Order", style: TextStyle(color: Colors.red)),
                          ),
                        )
                      else
                        const Expanded(
                          child: Text(
                            "NGO Claim Active",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _convertToPickup,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text("Self Pickup", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Icon(Icons.person, color: statusColor),
                      ),
                      title: Text(
                        orderData['riderName'] ?? orderData['volunteerName'] ?? "Volunteer Assigned",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(orderData['riderVehicle'] ?? "Bike / Vehicle"),
                      trailing: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: const Icon(Icons.call, color: Colors.green, size: 20),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                const Text(
                  "Share this OTP with Volunteer/Donor on delivery:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: primaryGreen, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        displayOtp,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text("Keep it confidential", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (status == 'Completed' || status == 'Delivered')
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check),
                        label: const Text("Back to Home"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}