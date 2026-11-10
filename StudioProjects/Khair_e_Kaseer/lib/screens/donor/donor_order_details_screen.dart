import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/donor/donor_handover_verify_screen.dart';
import 'package:khair_e_kaseer/screens/donor/donor_order_tracking_screen.dart';

class DonorOrderDetailsScreen extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> donationData;

  const DonorOrderDetailsScreen({
    super.key,
    required this.donationId,
    required this.donationData,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF347A5C);

    bool isBulk = donationData['isBulk'] == true || donationData['donationType'] == 'bulk';
    String foodTitle = donationData['foodName'] ?? donationData['foodTitle'] ?? "Order Details";

    String headerQuantityText;
    if (isBulk) {
      headerQuantityText = donationData['quantityDescription'] ?? "Bulk Quantity";
    } else {
      headerQuantityText = "Remaining: ${donationData['remainingPortions'] ?? 0} Portions";
    }

    String currentStatus = (donationData['status'] ?? '').toString().trim().toLowerCase();
    String claimedBy = donationData['claimedBy'] ?? donationData['claimedByUid'] ?? '';
    bool hasDirectClaim = claimedBy.isNotEmpty ||
        currentStatus == 'claimed' ||
        currentStatus == 'picked' ||
        currentStatus == 'completed' ||
        donationData['claimOtp'] != null ||
        donationData['otp'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: Text(foodTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: (donationData['foodImage'] != null && donationData['foodImage'].toString().isNotEmpty)
                        ? Image.memory(base64Decode(donationData['foodImage']), width: 90, height: 90, fit: BoxFit.cover)
                        : Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(foodTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(
                          headerQuantityText,
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Text("Active Claims & Tracking", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Orders')
                  .where('donationId', isEqualTo: donationId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }

                List<QueryDocumentSnapshot> orders = snapshot.hasData ? snapshot.data!.docs : [];

                if (orders.isEmpty && hasDirectClaim) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildClaimCard(
                          context,
                          donationId,
                          claimedBy,
                          donationData['quantityDescription'] ?? "Bulk Donation",
                          donationData['fulfillmentMethod'] ?? "Self Pickup",
                          donationData['status'] ?? 'Claimed',
                          isNgo: (donationData['claimedByRole'] ?? '').toString().toUpperCase() == 'NGO' || isBulk,
                          customOrderId: donationData['orderId'],
                        ),
                      ],
                    ),
                  );
                }

                if (orders.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text("No one has claimed this food yet.", style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    var order = orders[index];
                    var oData = order.data() as Map<String, dynamic>;

                    String quantityLabel = isBulk
                        ? (oData['quantityDescription'] ?? "Bulk Quantity")
                        : "${oData['portionsClaimed'] ?? 1} Portions";

                    return Column(
                      children: [
                        _buildClaimCard(
                          context,
                          order.id,
                          oData['beneficiaryId'] ?? oData['claimedBy'] ?? "",
                          quantityLabel,
                          oData['deliveryType'] ?? oData['fulfillmentMethod'] ?? "Pickup",
                          oData['status'] ?? 'Pending',
                          isNgo: oData['claimedByRole'] == 'NGO',
                          customOrderId: oData['orderId'],
                        ),

                        if (oData['volunteerId'] != null)
                          _buildVolunteerTrackingCard(oData),

                        const SizedBox(height: 10),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerTrackingCard(Map<String, dynamic> oData) {
    String status = (oData['status'] ?? 'Accepted').toString().toLowerCase();

    String trackingLabel = "Volunteer Arriving";
    if (status == 'picked') trackingLabel = "In Transit to Receiver";
    if (status == 'completed' || status == 'delivered') trackingLabel = "Delivery Finished";

    bool isCompleted = status == 'completed' || status == 'delivered';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.directions_bike,
                color: isCompleted ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 10),
              Text(
                trackingLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : Colors.blue,
                ),
              ),
              const Spacer(),
              if (!isCompleted)
                const Text("Live", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.blue)),
            title: Text(oData['riderName'] ?? "Volunteer Assigned", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Vehicle: ${oData['riderVehicle'] ?? "Bike"}"),
            trailing: !isCompleted ? const Icon(Icons.call, color: Colors.green) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(
      BuildContext context,
      String docId,
      String claimantId,
      String quantityText,
      String type,
      String rawStatus, {
        bool isNgo = false,
        String? customOrderId,
      }) {
    String displayId;
    if (customOrderId != null && customOrderId.isNotEmpty) {
      displayId = customOrderId.startsWith('#') ? customOrderId.substring(1) : customOrderId;
    } else {
      displayId = docId.length >= 6 ? "KF-${docId.substring(docId.length - 4).toUpperCase()}" : docId.toUpperCase();
    }

    String status = rawStatus.trim().toLowerCase();

    return Card(
      margin: const EdgeInsets.only(top: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNgo ? "Claimed by (NGO):" : "Beneficiary:",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (claimantId.isEmpty)
                      Text(
                        isNgo ? "Verified NGO Partner" : "Beneficiary User",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    else
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('Users').doc(claimantId).get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return const Text("Loading...", style: TextStyle(fontSize: 14, color: Colors.grey));
                          }

                          String fullName = isNgo ? "Registered NGO" : "Unknown User";
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            String first = userData['firstName'] ?? userData['organizationName'] ?? userData['name'] ?? "";
                            String last = userData['lastName'] ?? "";
                            fullName = "$first $last".trim();
                            if (fullName.isEmpty) fullName = isNgo ? "NGO Organization" : "Verified Account";
                          }
                          return Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
                        },
                      ),
                    const SizedBox(height: 5),
                    Text(
                      "Requested: $quantityText",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    type,
                    style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("Order: #$displayId", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF347A5C),
                          side: const BorderSide(color: Color(0xFF347A5C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.my_location, size: 14),
                        label: const Text("LIVE TRACKING", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DonorOrderTrackingScreen(orderId: docId),
                            ),
                          );
                        },
                      ),
                      if (status == 'completed' || status == 'delivered')
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.verified, color: Color(0xFF347A5C), size: 18),
                            SizedBox(width: 4),
                            Text("Delivered", style: TextStyle(color: Color(0xFF347A5C), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      else if (status == 'picked' || status == 'handed over')
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 4),
                            Text("Handed Over", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF347A5C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DonorHandoverVerifyScreen(correctOrderId: docId),
                              ),
                            );
                          },
                          child: const Text("CONFIRM HANDOVER", style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
