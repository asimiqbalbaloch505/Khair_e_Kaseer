import 'package:flutter/material.dart';
import 'package:khair_e_kaseer/screens/donor/donor_welcome_dashboard.dart';
import 'package:khair_e_kaseer/screens/donor/donor_active_listing_screen.dart';
import 'package:khair_e_kaseer/screens/donor/donor_alerts_screen.dart'; // Fixed import line
import 'package:khair_e_kaseer/screens/donor/post_food_item_screen.dart';
import 'package:khair_e_kaseer/screens/common/account_screen.dart';

class DonorMainNavigationScreen extends StatefulWidget {
  const DonorMainNavigationScreen({super.key});

  @override
  State<DonorMainNavigationScreen> createState() => _DonorMainNavigationScreenState();
}

class _DonorMainNavigationScreenState extends State<DonorMainNavigationScreen> {
  int _currentIndex = 0;

  final Color primaryGreen = const Color(0xFF347A5C);
  final Color accentAmber = const Color(0xFFD98E39);

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DonorWelcomeDashboardContent(onSwitchTab: _switchTab),
      const DonorActiveListingsScreen(),
      const DonorAlertsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PostFoodItemScreen()),
          );
        },
        backgroundColor: accentAmber,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0),
              _buildNavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Postings', index: 1),
              const SizedBox(width: 40),
              _buildNavItem(icon: Icons.notifications_none, activeIcon: Icons.notifications, label: 'Alerts', index: 2),
              _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Account', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? primaryGreen : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryGreen : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}