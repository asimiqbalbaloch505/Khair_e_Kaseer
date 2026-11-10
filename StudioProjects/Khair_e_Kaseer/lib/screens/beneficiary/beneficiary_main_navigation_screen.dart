import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khair_e_kaseer/screens/beneficiary/beneficiary_dashboard_screen.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';

class BeneficiaryMainNavigationScreen extends StatefulWidget {
  const BeneficiaryMainNavigationScreen({super.key});

  @override
  State<BeneficiaryMainNavigationScreen> createState() => _BeneficiaryMainNavigationScreenState();
}

class _BeneficiaryMainNavigationScreenState extends State<BeneficiaryMainNavigationScreen> {
  int _currentIndex = 0;
  final Color primaryGreen = const Color(0xFF347A5C);

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

  @override
  Widget build(BuildContext context) {
    bool isNgo = userRole.toUpperCase() == 'NGO';

    final List<Widget> screens = [
      const BeneficiaryDashboardScreen(initialTab: 0),
      const BeneficiaryDashboardScreen(initialTab: 1),
      BeneficiaryAlertsPlaceholder(isNgo: isNgo),
      const AccountScreen(),
    ];

    if (isLoadingRole) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFBF4),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(isNgo ? Icons.inventory_2_outlined : Icons.fastfood_outlined),
            activeIcon: Icon(isNgo ? Icons.inventory_2 : Icons.fastfood),
            label: isNgo ? 'Available Bulk' : 'Available Food',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in_outlined),
            activeIcon: Icon(Icons.assignment_turned_in),
            label: 'My Claims',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class BeneficiaryAlertsPlaceholder extends StatelessWidget {
  final bool isNgo;
  const BeneficiaryAlertsPlaceholder({super.key, required this.isNgo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF4),
      appBar: AppBar(
        title: Text(isNgo ? "NGO Bulk Alerts" : "Food Alerts",
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFBFBF4),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              isNgo ? "No new bulk food alerts." : "No new food availability alerts.",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}