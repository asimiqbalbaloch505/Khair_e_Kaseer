import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VolunteerAlertsScreen extends StatelessWidget {
  const VolunteerAlertsScreen({super.key});

  final Color primaryGreen = const Color(0xFF347A5C);

  Future<void> _clearAllNotifications() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Notifications')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final role = (data['targetRole'] ?? '').toString().toLowerCase();
        final topic = (data['topic'] ?? '').toString().toLowerCase();
        final receiverId = data['receiverId'] ?? data['userId'] ?? '';

        if (role == 'volunteer' ||
            topic.contains('volunteer') ||
            (currentUserId != null && receiverId == currentUserId)) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          "Alerts & Notifications",
          style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep, color: primaryGreen),
            tooltip: "Clear All",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear Notifications"),
                  content: const Text(
                      "Are you sure you want to clear all volunteer notifications?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _clearAllNotifications();
                      },
                      child: const Text("Clear All",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: currentUserId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('Users')
                .doc(currentUserId)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots()
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryGreen));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Error loading alerts: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text("No alerts available yet.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Case-insensitive filtering for targetRole, topic, or receiverId
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String targetRole = (data['targetRole'] ?? '').toString().toLowerCase();
            final String topic = (data['topic'] ?? '').toString().toLowerCase();
            final String receiverId = (data['receiverId'] ?? data['userId'] ?? '').toString();

            return targetRole == 'volunteer' ||
                topic.contains('volunteer') ||
                (currentUserId.isNotEmpty && receiverId == currentUserId);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text("No alerts available yet.",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Sort in-memory safely to handle null/pending serverTimestamps
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            dynamic aTime = aData['createdAt'];
            dynamic bTime = bData['createdAt'];

            DateTime aDate = aTime is Timestamp
                ? aTime.toDate()
                : (aTime is int
                ? DateTime.fromMillisecondsSinceEpoch(aTime)
                : DateTime.now());

            DateTime bDate = bTime is Timestamp
                ? bTime.toDate()
                : (bTime is int
                ? DateTime.fromMillisecondsSinceEpoch(bTime)
                : DateTime.now());

            return bDate.compareTo(aDate);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final alert = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final bool isRead = alert['isRead'] == true;

              dynamic rawTimestamp = alert['createdAt'];
              DateTime date = rawTimestamp is Timestamp
                  ? rawTimestamp.toDate()
                  : (rawTimestamp is int
                  ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
                  : DateTime.now());

              String formattedTime =
                  "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}";

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: isRead ? Colors.white : const Color(0xFFF0F7F4),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryGreen.withOpacity(0.1),
                        child: Icon(Icons.notifications_active,
                            color: primaryGreen),
                      ),
                      if (!isRead)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    alert['title'] ?? 'Alert',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        alert['body'] ?? '',
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedTime,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      FirebaseFirestore.instance
                          .collection('Notifications')
                          .doc(docId)
                          .update({'isRead': true});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}