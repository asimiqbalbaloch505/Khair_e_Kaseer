import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/volunteer/volunteer_dashboard_screen.dart';
import 'package:khair_e_kaseer/screens/volunteer/volunteer_my_tasks_screen.dart'; // <-- Import new screen
import 'package:khair_e_kaseer/screens/volunteer/volunteer_alerts_screen.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';
import 'package:khair_e_kaseer/services/fcm_client_service.dart';

class VolunteerMainNavigationScreen extends StatefulWidget {
  const VolunteerMainNavigationScreen({super.key});

  @override
  State<VolunteerMainNavigationScreen> createState() =>
      _VolunteerMainNavigationScreenState();
}

class _VolunteerMainNavigationScreenState
    extends State<VolunteerMainNavigationScreen> {
  int _currentIndex = 0;
  final Color primaryGreen = const Color(0xFF347A5C);

  final List<Widget> _screens = [
    const VolunteerDashboard(),
    const VolunteerMyTasksScreen(), // <-- Separate Screen Widget
    const VolunteerAlertsScreen(),
    const AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      await FCMClientService.saveTokenToDatabase();
      if (mounted) {
        FCMClientService.listenToForegroundMessages(context);
      }
    } catch (e) {
      debugPrint("Error initializing FCM in VolunteerMainNavigationScreen: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.two_wheeler_outlined),
            activeIcon: Icon(Icons.two_wheeler),
            label: "My Tasks",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: "Alerts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Account",
          ),
        ],
      ),
    );
  }
}