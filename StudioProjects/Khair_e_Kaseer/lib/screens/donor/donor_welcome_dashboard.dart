import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/donor/donor_active_listing_screen.dart';
import 'package:khair_e_kaseer/screens/donor/donor_order_details_screen.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';

class DonorWelcomeDashboard extends StatelessWidget {
  final Function(int)? onSwitchTab;
  const DonorWelcomeDashboard({super.key, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return DonorWelcomeDashboardContent(onSwitchTab: onSwitchTab);
  }
}

class DonorWelcomeDashboardContent extends StatefulWidget {
  final Function(int)? onSwitchTab;
  const DonorWelcomeDashboardContent({super.key, this.onSwitchTab});

  @override
  State<DonorWelcomeDashboardContent> createState() => _DonorWelcomeDashboardContentState();
}

class _DonorWelcomeDashboardContentState extends State<DonorWelcomeDashboardContent> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryGreen = const Color(0xFF347A5C);

  String userName = "Loading...";
  int totalMealsUploaded = 0;
  int activePostings = 0;
  int deliveredOrdersCount = 0;

  List<int> weeklyActivity = [0, 0, 0, 0, 0, 0, 0];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndAnalytics();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _fetchUserDataAndAnalytics();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Cleans up inactive non-bulk donations
  Future<void> _checkAndCleanupDonation(String docId, Map<String, dynamic> data) async {
    bool shouldDelete = false;

    // Expiry Check
    if (data['expiryDateTime'] != null) {
      DateTime expiryTime = (data['expiryDateTime'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryTime)) {
        shouldDelete = true;
      }
    }

    // Status Check
    String status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status == 'expired' || status == 'out of stock') {
      shouldDelete = true;
    }

    // Zero Portions Check (Only for non-bulk items when fully consumed)
    bool isBulk = data['isBulk'] == true || data['donationType'] == 'bulk';
    if (!isBulk && data['remainingPortions'] != null) {
      var remaining = data['remainingPortions'];
      if ((remaining is int && remaining <= 0) || (remaining is String && remaining == '0')) {
        if (status != 'claimed' && status != 'pending') {
          shouldDelete = true;
        }
      }
    }

    if (shouldDelete) {
      try {
        await FirebaseFirestore.instance.collection('Donations').doc(docId).delete();
        debugPrint("Cleaned up inactive donation doc: $docId");
      } catch (e) {
        debugPrint("Error auto-deleting document $docId: $e");
      }
    }
  }

  Future<List<QueryDocumentSnapshot>> _getDonorDocuments(String collectionName) async {
    if (currentUser == null) return [];

    final collection = FirebaseFirestore.instance.collection(collectionName);
    Map<String, QueryDocumentSnapshot> docMap = {};

    List<String> keys = ['donorId', 'donorUid', 'donor_id', 'userId'];
    for (String key in keys) {
      try {
        QuerySnapshot snap = await collection.where(key, isEqualTo: currentUser!.uid).get();
        for (var doc in snap.docs) {
          docMap[doc.id] = doc;
        }
      } catch (e) {
        debugPrint("Error querying $collectionName for key $key: $e");
      }
    }

    return docMap.values.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchDonorOrders() async {
    if (currentUser == null) return [];

    List<Map<String, dynamic>> orderList = [];
    Set<String> processedOrderIds = {};
    List<String> donorKeys = ['donorId', 'donorUid', 'donor_id', 'userId'];

    try {
      for (String key in donorKeys) {
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection('Orders')
            .where(key, isEqualTo: currentUser!.uid)
            .get();

        for (var doc in snap.docs) {
          if (!processedOrderIds.contains(doc.id)) {
            processedOrderIds.add(doc.id);
            orderList.add(doc.data() as Map<String, dynamic>);
          }
        }
      }

      for (String key in donorKeys) {
        QuerySnapshot groupSnap = await FirebaseFirestore.instance
            .collectionGroup('Orders')
            .where(key, isEqualTo: currentUser!.uid)
            .get();

        for (var doc in groupSnap.docs) {
          if (!processedOrderIds.contains(doc.id)) {
            processedOrderIds.add(doc.id);
            orderList.add(doc.data() as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching donor orders: $e");
    }

    return orderList;
  }

  Future<void> _fetchUserDataAndAnalytics() async {
    if (currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          userName = userDoc['firstName'] ?? userDoc['name'] ?? "Donor";
        });
      }

      List<QueryDocumentSnapshot> activeDocs = await _getDonorDocuments('Donations');
      List<Map<String, dynamic>> orders = await _fetchDonorOrders();

      int completedCount = 0;
      int totalPortionsDelivered = 0;

      for (var data in orders) {
        String st = (data['status'] ?? '').toString().trim().toLowerCase();

        if (st == 'completed' || st == 'delivered' || st == 'picked' || st == 'picked up' || st == 'claimed') {
          completedCount++;
          var claimed = data['portionsClaimed'] ?? data['quantity'] ?? 1;
          if (claimed is int) {
            totalPortionsDelivered += claimed;
          } else if (claimed is String) {
            totalPortionsDelivered += int.tryParse(claimed) ?? 1;
          } else {
            totalPortionsDelivered += 1;
          }
        }
      }

      int activePortionsCount = 0;
      for (var doc in activeDocs) {
        var data = doc.data() as Map<String, dynamic>;
        var remaining = data['remainingPortions'] ?? data['quantity'] ?? 1;
        if (remaining is int) {
          activePortionsCount += remaining;
        } else if (remaining is String) {
          activePortionsCount += int.tryParse(remaining) ?? 1;
        } else {
          activePortionsCount += 1;
        }
      }

      List<int> weekDaysData = List.filled(7, 0);
      DateTime now = DateTime.now();

      void processTimestamp(dynamic ts) {
        if (ts is Timestamp) {
          DateTime date = ts.toDate();
          int diffDays = now.difference(date).inDays;
          if (diffDays >= 0 && diffDays < 7) {
            int weekdayIndex = date.weekday - 1;
            weekDaysData[weekdayIndex]++;
          }
        }
      }

      for (var doc in activeDocs) {
        processTimestamp((doc.data() as Map<String, dynamic>)['timestamp']);
      }
      for (var orderData in orders) {
        processTimestamp(orderData['timestamp']);
      }

      if (mounted) {
        setState(() {
          activePostings = activeDocs.length;
          deliveredOrdersCount = completedCount;
          totalMealsUploaded = activePortionsCount + totalPortionsDelivered;
          weeklyActivity = weekDaysData;
        });
      }
    } catch (e) {
      debugPrint("Error calculating donor stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgGrey = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgGrey,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchUserDataAndAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Donor Dashboard",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.onSwitchTab?.call(2); // Switches to Alerts tab
                      },
                      icon: const Icon(Icons.notifications_none, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome back,",
                          style: TextStyle(fontSize: 16, color: Colors.black54, decoration: TextDecoration.none),
                        ),
                        Text(
                          "$userName!",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AccountScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: primaryGreen.withOpacity(0.1),
                        child: Icon(Icons.person, color: primaryGreen),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 25),

                _buildMainStatCard("Total Meals Contributed:", totalMealsUploaded.toString()),

                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(child: _buildSmallStatCard("Active Postings", activePostings.toString(), Icons.nature_people_outlined, Colors.green)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildSmallStatCard("Delivered / Picked", deliveredOrdersCount.toString(), Icons.check_circle_outline, Colors.blue)),
                  ],
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Active Postings",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                    ),
                    TextButton(
                      onPressed: () {
                        if (widget.onSwitchTab != null) {
                          widget.onSwitchTab!(1); // Switches tab to Postings (index 1)
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DonorActiveListingsScreen()),
                          );
                        }
                      },
                      child: Text("View All", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                _buildPostingsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard(String title, String value) {
    List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];
    int maxVal = weeklyActivity.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 20),
          const Text(
            "Weekly Activity Trend",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              double count = weeklyActivity[index].toDouble();
              double fillPercent = count / maxVal;
              double height = 10 + (fillPercent * 40);

              return Column(
                children: [
                  Text(
                    "${weeklyActivity[index]}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: height,
                    width: 14,
                    decoration: BoxDecoration(
                      color: count > 0 ? primaryGreen : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekDays[index],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, decoration: TextDecoration.none),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.none),
              ),
              Icon(icon, color: iconColor, size: 28),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostingsList() {
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Donations')
          .where('donorId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Color(0xFF347A5C)),
            ),
          );
        }

        List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "No active postings right now.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length > 5 ? 5 : docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;

            _checkAndCleanupDonation(doc.id, data);

            String remainingTimeText = "Soon";
            bool isExpired = false;

            if (data['expiryDateTime'] != null) {
              DateTime expiryTime = (data['expiryDateTime'] as Timestamp).toDate();
              Duration diff = expiryTime.difference(DateTime.now());
              if (diff.isNegative) {
                isExpired = true;
                remainingTimeText = "Expired";
              } else {
                if (diff.inHours > 0) {
                  remainingTimeText = "${diff.inHours}h ${diff.inMinutes % 60}m left";
                } else {
                  remainingTimeText = "${diff.inMinutes}m left";
                }
              }
            }

            String status = isExpired ? "Expired" : (data['status'] ?? 'Available');
            Color statusBg = (status.toLowerCase() == 'available')
                ? Colors.green.shade700
                : (status.toLowerCase() == 'expired' ? Colors.red : Colors.orange);

            bool isBulk = data['isBulk'] == true || data['donationType'] == 'bulk';
            String titleQuantityText;
            String foodTitle = data['foodName'] ?? data['foodTitle'] ?? 'Food Item';

            if (isBulk) {
              String bulkQty = data['quantityDescription'] ?? data['quantity']?.toString() ?? 'Bulk Quantity';
              titleQuantityText = "$foodTitle - $bulkQty (NGO)";
            } else {
              var displayQty = data['remainingPortions'] ?? data['quantity'] ?? "0";
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
              child: Card(
                margin: const EdgeInsets.only(bottom: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: (data['foodImage'] != null && data['foodImage'].toString().isNotEmpty)
                            ? Image.memory(base64Decode(data['foodImage']), width: 70, height: 70, fit: BoxFit.cover)
                            : Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.fastfood, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleQuantityText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isExpired ? "Post Expired" : "Expires: $remainingTimeText",
                              style: TextStyle(color: isExpired ? Colors.red : Colors.black54, fontSize: 12, decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusBg, fontWeight: FontWeight.bold, fontSize: 10, decoration: TextDecoration.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}