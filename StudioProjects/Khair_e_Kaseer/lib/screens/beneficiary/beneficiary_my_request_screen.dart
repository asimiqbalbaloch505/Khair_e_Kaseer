import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_rider_tracking_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_self_pickup_tracking.dart';

class BeneficiaryMyRequestScreen extends StatelessWidget {
  const BeneficiaryMyRequestScreen({super.key});

  final Color primaryGreen = const Color(0xFF347A5C);

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("My Food Requests", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: primaryGreen),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Orders')
            .where('claimedBy', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Fallback Stream checking Donations collection directly
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Donations')
                  .where('claimedBy', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, altSnapshot) {
                if (altSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!altSnapshot.hasData || altSnapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No requests found.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return _buildList(altSnapshot.data!.docs);
              },
            );
          }

          return _buildList(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var orderData = docs[index].data() as Map<String, dynamic>;
        var docId = orderData['orderDocId'] ?? docs[index].id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _buildRequestTile(context, docId, orderData),
        );
      },
    );
  }

  Widget _buildRequestTile(BuildContext context, String docId, Map<String, dynamic> data) {
    String status = data['status'] ?? "Pending";
    String type = data['deliveryType'] ?? data['fulfillmentMethod'] ?? "Delivery";
    String foodName = data['foodTitle'] ?? data['foodName'] ?? "Food Item";
    String portions = (data['portionsClaimed'] ?? data['quantityDescription'] ?? "1").toString();

    Color statusColor;
    IconData statusIcon;

    bool isPickup = type.toLowerCase().contains("pickup");

    if (status.toLowerCase() == "completed" || status.toLowerCase() == "delivered") {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isPickup) {
      statusColor = Colors.orange;
      statusIcon = Icons.front_hand_outlined;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.directions_bike;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(foodName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Type: $type • Portions: $portions"),
            Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (status.toLowerCase() != "completed" && status.toLowerCase() != "delivered") {
            if (isPickup) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BeneficiarySelfPickupTrackingScreen(orderDocId: docId)),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BeneficiaryRiderTrackingScreen(orderDocId: docId)),
              );
            }
          }
        },
      ),
    );
  }
}