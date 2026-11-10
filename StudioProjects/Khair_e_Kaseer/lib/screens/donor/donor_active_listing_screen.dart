import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khair_e_kaseer/screens/donor/donor_order_details_screen.dart';

class DonorActiveListingsScreen extends StatelessWidget {
  const DonorActiveListingsScreen({super.key});

  Future<void> _updateDatabaseStatus(String docId, String currentStatus) async {
    if (currentStatus == 'Available') {
      try {
        await FirebaseFirestore.instance
            .collection('Donations')
            .doc(docId)
            .update({'status': 'Expired'});
      } catch (e) {
        debugPrint("Status update error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    const Color primaryGreen = Color(0xFF347A5C);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Food Postings",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: const [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          SizedBox(width: 15),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
            child: Text(
              "Manage Your Listings",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Donations')
                  .where('donorId', isEqualTo: currentUser?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "You haven't posted any food yet.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    // --- Real-time Expiry Logic ---
                    String expiryLabel = "Calculating...";
                    bool isActuallyExpired = false;

                    if (data['expiryDateTime'] != null) {
                      DateTime expiryTime = (data['expiryDateTime'] as Timestamp).toDate();
                      Duration diff = expiryTime.difference(DateTime.now());

                      if (diff.isNegative) {
                        isActuallyExpired = true;
                        expiryLabel = "Expired";
                        _updateDatabaseStatus(doc.id, data['status'] ?? 'Available');
                      } else {
                        expiryLabel = diff.inHours > 0 ? "${diff.inHours}h left" : "${diff.inMinutes}m left";
                      }
                    }

                    String displayStatus = isActuallyExpired ? "Expired" : (data['status'] ?? 'Pending');

                    Color statusButtonColor;
                    if (displayStatus == 'Available') {
                      statusButtonColor = primaryGreen;
                    } else if (displayStatus == 'Expired') {
                      statusButtonColor = Colors.redAccent;
                    } else {
                      statusButtonColor = const Color(0xFFD98E39);
                    }

                    // --- Bulk vs Portion Display Formatting ---
                    bool isBulk = data['isBulk'] == true || data['donationType'] == 'bulk';
                    String titleQuantityText;

                    if (isBulk) {
                      String bulkQty = data['quantityDescription'] ?? 'Bulk Quantity';
                      String foodTitle = data['foodName'] ?? data['foodTitle'] ?? 'Food';
                      titleQuantityText = "$foodTitle - $bulkQty (NGO)";
                    } else {
                      var displayQty = data['remainingPortions'] ?? data['quantity'] ?? "0";
                      String foodTitle = data['foodName'] ?? data['foodTitle'] ?? 'Food';
                      titleQuantityText = "$foodTitle - $displayQty Portions";
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DonorOrderDetailsScreen(
                              donationId: doc.id,
                              donationData: data,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Image Section
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (data['foodImage'] != null && data['foodImage'].toString().isNotEmpty)
                                    ? Image.memory(
                                  base64Decode(data['foodImage']),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.grey[100],
                                  child: const Icon(Icons.fastfood, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 15),
                              // Info Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titleQuantityText,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "(Expires: $expiryLabel)",
                                      style: TextStyle(
                                        color: isActuallyExpired ? Colors.red : Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Status Label / Button
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: statusButtonColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "VIEW DETAILS & CLAIMS",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}