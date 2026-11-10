import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:khair_e_kaseer/widgets/widgets.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryGreen = const Color(0xFF347A5C);

  String _selectedFilter = 'All'; // 'All', 'Unread', 'SOP Warnings'

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please log in to view notifications.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Notification Center",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18, color: Color(0xFF347A5C)),
            label: const Text("Mark Read", style: TextStyle(color: Color(0xFF347A5C), fontSize: 12)),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread'),
                const SizedBox(width: 8),
                _buildFilterChip('SOP Warnings'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notification Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(currentUser!.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryGreen));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.notifications_off_outlined,
                    title: "No notifications yet",
                    subtitle: "SOP alerts & system notifications will appear here.",
                  );
                }

                List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                // Apply client-side filter
                if (_selectedFilter == 'Unread') {
                  docs = docs.where((doc) {
                    Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
                    return d['isRead'] != true;
                  }).toList();
                } else if (_selectedFilter == 'SOP Warnings') {
                  docs = docs.where((doc) {
                    Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
                    String type = (d['type'] ?? d['sopCategory'] ?? '').toString();
                    return type.toLowerCase().contains('sop') || type.toLowerCase().contains('warning');
                  }).toList();
                }

                if (docs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.filter_alt_off_outlined,
                    title: "No notifications found for '$_selectedFilter'",
                    subtitle: "Try selecting a different filter above.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String notifId = doc.id;

                    String title = data['title'] ?? 'Notification';
                    String body = data['body'] ?? '';
                    String category = data['sopCategory'] ?? data['type'] ?? 'General SOP';
                    bool isRead = data['isRead'] == true;

                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    String formattedTime = ts != null
                        ? DateFormat('MMM dd, hh:mm a').format(ts.toDate())
                        : 'Just now';

                    bool isWarningType = title.toLowerCase().contains('warning') ||
                        title.toLowerCase().contains('flag') ||
                        title.toLowerCase().contains('alert') ||
                        category.toLowerCase().contains('sop');

                    Color themeColor = isWarningType ? Colors.amber.shade900 : primaryGreen;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: isRead ? 0.3 : 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: !isRead ? themeColor.withOpacity(0.4) : Colors.grey.shade200,
                          width: !isRead ? 1.2 : 1,
                        ),
                      ),
                      child: ExpansionTile(
                        onExpansionChanged: (expanded) {
                          if (!isRead) _markAsRead(notifId);
                        },
                        leading: CircleAvatar(
                          backgroundColor: themeColor.withOpacity(0.12),
                          child: Icon(
                            isWarningType ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
                            color: themeColor,
                            size: 22,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          "$formattedTime | Category: $category",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    body,
                                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // SOP Compliance Advice
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade800),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Compliance Guidance: Adhering to Khair-e-Kaseer SOPs ensures safe food delivery and keeps your account in good standing.",
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: primaryGreen.withOpacity(0.18),
      checkmarkColor: primaryGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? primaryGreen : Colors.black87,
      ),
      onSelected: (selected) {
        setState(() => _selectedFilter = label);
      },
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notification read: $e");
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      QuerySnapshot unreadSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadSnap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("All notifications marked as read."),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking all read: $e");
    }
  }
}
