import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonorAlertsScreen extends StatelessWidget {
  const DonorAlertsScreen({super.key});

  /// Deletes all notifications associated with the current user or donor role
  Future<void> _clearAllNotifications(
      BuildContext context, List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Notifications"),
        content: const Text(
            "Are you sure you want to delete all notifications? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmDelete) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications cleared successfully."),
            backgroundColor: Color(0xFF347A5C),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error clearing notifications: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    const Color primaryGreen = Color(0xFF347A5C);

    return StreamBuilder<QuerySnapshot>(
      stream: currentUser != null
          ? FirebaseFirestore.instance
              .collection('Users')
              .doc(currentUser.uid)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        List<QueryDocumentSnapshot> docs = snapshot.hasData ? snapshot.data!.docs : [];

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Donor Notifications",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryGreen,
            elevation: 0,
            actions: [
              if (docs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  tooltip: "Clear All",
                  onPressed: () => _clearAllNotifications(context, docs),
                ),
            ],
          ),
          body: currentUser == null
              ? const Center(child: Text("Please login to view notifications."))
              : snapshot.connectionState == ConnectionState.waiting
              ? const Center(
            child: CircularProgressIndicator(color: primaryGreen),
          )
              : docs.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const Text(
                  "No notifications yet",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data =
              docs[index].data() as Map<String, dynamic>;
              String title = data['title'] ?? 'Notification';
              String body = data['body'] ?? '';
              Timestamp? ts = (data['timestamp'] ??
                  data['createdAt']) as Timestamp?;
              String timeStr = ts != null
                  ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                  : '';

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: primaryGreen.withOpacity(0.1),
                    child: const Icon(
                      Icons.notifications,
                      color: primaryGreen,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: Colors.grey.shade400),
                    onPressed: () async {
                      await docs[index].reference.delete();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}