import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/volunteer/pickup_details_screen.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);
  final String currentVolunteerId = FirebaseAuth.instance.currentUser?.uid ?? "";

  String vehicleType = "";

  @override
  void initState() {
    super.initState();
    _fetchVolunteerProfile();
  }

  Future<void> _fetchVolunteerProfile() async {
    if (currentVolunteerId.isEmpty) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentVolunteerId)
          .get();

      if (userDoc.exists && mounted) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> vData = data['verificationData'] is Map<String, dynamic>
            ? data['verificationData'] as Map<String, dynamic>
            : {};

        setState(() {
          vehicleType = (vData['vehicleType'] ?? data['vehicleType'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
        });
      }
    } catch (e) {
      debugPrint("Error fetching volunteer vehicle profile: $e");
    }
  }

  bool _isBulkOrderAllowed() {
    return vehicleType.contains('van') ||
        vehicleType.contains('cargo') ||
        vehicleType.contains('truck') ||
        vehicleType.contains('loader');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          "Volunteer Dashboard",
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle_outlined, color: primaryGreen, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountScreen()),
              );
            },
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: Icon(Icons.logout, color: primaryGreen),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Assalam-o-Alaikum,", style: TextStyle(fontSize: 16)),
                const Text("Volunteer Partner",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                if (vehicleType.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Vehicle: ${vehicleType.toUpperCase()} (${_isBulkOrderAllowed() ? "Bulk Transport Eligible" : "Standard Transport"})",
                      style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("Available Deliveries Near You:",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Orders')
                  .where('status', isEqualTo: 'Pending')
                  .where('deliveryType', isEqualTo: 'Delivery')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No pending deliveries!", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                bool canCarryBulk = _isBulkOrderAllowed();

                // Vehicle-based filtration
                final orders = snapshot.data!.docs.where((doc) {
                  var orderData = doc.data() as Map<String, dynamic>;
                  bool isBulk = orderData['isBulk'] == true || orderData['donationType'] == 'bulk';
                  return canCarryBulk ? isBulk : !isBulk;
                }).toList();

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          canCarryBulk
                              ? "No pending bulk orders matching your vehicle size!"
                              : "No pending standard orders matching your vehicle size!",
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    var orderData = orders[index].data() as Map<String, dynamic>;
                    var orderDocId = orders[index].id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.fastfood, color: Colors.orange),
                            ),
                            title: Text(orderData['foodName'] ?? "Food Item", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${orderData['portionsClaimed'] ?? orderData['quantity'] ?? 'N/A'} Portions requested"),
                            trailing: const Text("NEW", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const Divider(),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PickupDetailsScreen(
                                      orderId: orderDocId,
                                      orderData: orderData,
                                    ),
                                  ),
                                );
                              },
                              child: const Text("View Details & Accept", style: TextStyle(color: Colors.white)),
                            ),
                          )
                        ],
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