import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/login_form_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_food_details_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_rider_tracking_screen.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_self_pickup_tracking.dart';

class BeneficiaryDashboardScreen extends StatefulWidget {
  final int initialTab;
  const BeneficiaryDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<BeneficiaryDashboardScreen> createState() => _BeneficiaryDashboardScreenState();
}

class _BeneficiaryDashboardScreenState extends State<BeneficiaryDashboardScreen> {
  final Color primaryGreen = const Color(0xFF347A5C);
  final Color bgCream = const Color(0xFFFBFBF4);

  String userRole = 'Beneficiary';
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              userRole = (data['role'] ?? 'Beneficiary').toString();
              isLoadingRole = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("Error fetching user role: $e");
      }
    }
    if (mounted) {
      setState(() => isLoadingRole = false);
    }
  }

  /// Helper method to check whether a donation is expired
  bool _isDonationExpired(Map<String, dynamic> data) {
    DateTime now = DateTime.now();

    // 1. Check if expiry exists as Timestamp
    if (data['expiryDate'] is Timestamp) {
      DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
      if (expiry.isBefore(now)) return true;
    } else if (data['expiryTime'] is Timestamp) {
      DateTime expiry = (data['expiryTime'] as Timestamp).toDate();
      if (expiry.isBefore(now)) return true;
    }

    // 2. Check if expiry exists as ISO String or formatted String
    if (data['expiryDate'] is String && (data['expiryDate'] as String).isNotEmpty) {
      DateTime? parsedDate = DateTime.tryParse(data['expiryDate']);
      if (parsedDate != null && parsedDate.isBefore(now)) return true;
    } else if (data['expiryTime'] is String && (data['expiryTime'] as String).isNotEmpty) {
      DateTime? parsedDate = DateTime.tryParse(data['expiryTime']);
      if (parsedDate != null && parsedDate.isBefore(now)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    bool isNgo = userRole.toUpperCase() == 'NGO';

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        title: Text(
          widget.initialTab == 1
              ? 'My Claimed Orders'
              : (isNgo ? 'NGO Bulk Food Portal' : 'Available Food Assistance'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: bgCream,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginFormScreen()),
                      (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: isLoadingRole
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : (widget.initialTab == 0 ? _buildAvailableFoodFeed(isNgo) : _buildMyClaimedRequests()),
    );
  }

  Widget _buildAvailableFoodFeed(bool isNgo) {
    Query foodQuery = FirebaseFirestore.instance
        .collection('Donations')
        .where('status', isEqualTo: 'Available');

    return StreamBuilder<QuerySnapshot>(
      stream: foodQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryGreen));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              isNgo
                  ? "No bulk food donations available."
                  : "No food items currently available for request.",
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          );
        }

        final rawDocs = snapshot.data!.docs;
        final donations = rawDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Filter out expired food items
          if (_isDonationExpired(data)) {
            return false;
          }

          String type = (data['donationType'] ?? 'individual').toString().toLowerCase();

          if (isNgo) {
            return type == 'bulk';
          } else {
            return type != 'bulk';
          }
        }).toList();

        if (donations.isEmpty) {
          return Center(
            child: Text(
              isNgo
                  ? "No bulk food donations available."
                  : "No food items currently available for request.",
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: donations.length,
          itemBuilder: (context, index) {
            final doc = donations[index];
            final data = doc.data() as Map<String, dynamic>;

            String foodNameDisplay = data['foodTitle'] ?? data['foodName'] ?? 'Food Item';
            dynamic rawRemaining = data['remainingPortions'] ?? data['portions'] ?? 1;
            int remaining = rawRemaining is int
                ? rawRemaining
                : int.tryParse(rawRemaining.toString()) ?? 1;

            String quantityDisplay = isNgo
                ? (data['quantityDescription'] ?? 'Bulk Quantity')
                : 'Remaining Portions: $remaining';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            foodNameDisplay,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isNgo ? "Bulk Donation" : "$remaining Portions Left",
                            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      quantityDisplay,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Pickup Location: ${data['pickupAddress'] ?? data['address'] ?? 'Address provided upon claim'}",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BeneficiaryFoodDetailsScreen(
                                foodId: doc.id,
                                foodData: data,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          isNgo ? 'View Details & Claim Bulk' : 'Request Food',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyClaimedRequests() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('claimedBy', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryGreen));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Donations')
                .where('claimedBy', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, altSnapshot) {
              if (altSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              if (!altSnapshot.hasData || altSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("You have no active claims."));
              }

              return _buildFilteredClaimsList(altSnapshot.data!.docs);
            },
          );
        }

        return _buildFilteredClaimsList(snapshot.data!.docs);
      },
    );
  }

  Widget _buildFilteredClaimsList(List<QueryDocumentSnapshot> docs) {
    final activeDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      String status = (data['status'] ?? '').toString().trim().toLowerCase();
      return status != 'picked' && status != 'completed' && status != 'handed over' && status != 'delivered';
    }).toList();

    if (activeDocs.isEmpty) {
      return const Center(
        child: Text("No active pending claims.", style: TextStyle(color: Colors.grey, fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: activeDocs.length,
      itemBuilder: (context, index) {
        final doc = activeDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final String fulfillment = data['deliveryType'] ?? data['fulfillmentMethod'] ?? 'Self Pickup';
        final String title = data['foodTitle'] ?? data['foodName'] ?? 'Food Claim';
        final String quantity = (data['portionsClaimed'] ?? data['quantityDescription'] ?? '1 Portion').toString();
        final String targetOrderDocId = data['orderDocId'] ?? doc.id;

        String rawStatus = (data['status'] ?? '').toString().trim();
        String status = (rawStatus.isEmpty || rawStatus.toLowerCase() == 'pending') ? 'Claimed' : rawStatus;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Quantity: $quantity", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  Text("Method: $fulfillment | Status: $status", style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (fulfillment.toLowerCase().contains('pickup')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BeneficiarySelfPickupTrackingScreen(orderDocId: targetOrderDocId),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BeneficiaryRiderTrackingScreen(orderDocId: targetOrderDocId),
                    ),
                  );
                }
              },
              child: const Text('Track', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}