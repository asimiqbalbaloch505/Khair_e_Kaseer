import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/volunteer/active_tracking_screen.dart';

class VolunteerMyTasksScreen extends StatelessWidget {
  const VolunteerMyTasksScreen({super.key});

  final Color primaryGreen = const Color(0xFF347A5C);

  @override
  Widget build(BuildContext context) {
    final String currentVolunteerId =
        FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        title: const Text(
          "My Active Tasks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryGreen,
        elevation: 0.5,
      ),
      body: currentVolunteerId.isEmpty
          ? const Center(
        child: Text(
          "Please sign in to view active tasks.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Orders')
            .where('volunteerId', isEqualTo: currentVolunteerId)
            .where('status',
            whereIn: ['Accepted', 'Picked', 'In Transit'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading active tasks: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No active rides or deliveries in progress",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final activeOrders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              var activeOrder = activeOrders[index];
              var activeData =
              activeOrder.data() as Map<String, dynamic>;
              String status = activeData['status'] ?? '';
              bool isPickupPhase = (status == 'Accepted');

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isPickupPhase
                      ? primaryGreen
                      : Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 5)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activeData['foodName'] ?? "Food Item",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          isPickupPhase
                              ? Icons.directions_run
                              : Icons.delivery_dining,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isPickupPhase
                          ? "Phase: Pickup from Donor"
                          : "Phase: Deliver to Receiver",
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: isPickupPhase
                              ? primaryGreen
                              : Colors.orange.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveTrackingScreen(
                                orderId: activeOrder.id,
                                isPickupMode: isPickupPhase,
                                stepTitle: isPickupPhase
                                    ? "Pickup Food"
                                    : "Deliver Food",
                                destinationName: isPickupPhase
                                    ? (activeData['donorName'] ??
                                    "Donor")
                                    : (activeData['receiverName'] ??
                                    "Receiver"),
                                destinationAddress: isPickupPhase
                                    ? (activeData['donorAddress'] ??
                                    "Address")
                                    : (activeData['receiverAddress'] ??
                                    "Address"),
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "RESUME TASK",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}