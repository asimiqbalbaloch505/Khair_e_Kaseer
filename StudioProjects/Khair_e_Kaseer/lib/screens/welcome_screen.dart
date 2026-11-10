import 'package:flutter/material.dart';
// Nayi file ko import karna lazmi hai navigation ke liye
import 'package:khair_e_kaseer/screens/login_form_screen.dart';
import 'package:khair_e_kaseer/screens/signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Design Colors
  final Color primaryGreen = const Color(0xFF1B5E20);
  final Color lightGreenBg = const Color(0xFFFBFBF4);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreenBg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Swipeable Section
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 1
                  _buildSwipePage(
                    title: 'Stop the waste,\nStart sharing',
                    subtitle: '“Turn excess into access - help food\nreach those who need it most.”',
                    image1: 'assets/images/Login_Page_Main_Logo.png',
                    image2: 'assets/images/Login_Page_Mini_Logo.png',
                    image3: 'assets/images/Login_Page_Mini_Logo.png',
                    isSecondPage: false,
                  ),

                  // Page 2
                  _buildSwipePage(
                    title: 'Join the mission, share food,\nspread smiles.',
                    subtitle: '“Fresh food, zero waste, just a tap away.”',
                    image1: 'assets/images/2nd_Login_Page_Main_Logo.png',
                    image2: 'assets/images/2nd_Login_Page_Upper_Logo.png',
                    image3: 'assets/images/2nd_Login_Page_Lower_left_Logo.png',
                    isSecondPage: true,
                  ),
                ],
              ),
            ),

            // 2. Dots Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (index) => _buildDot(index)),
              ),
            ),

            // 3. Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
              child: Column(
                children: [
                  // LOGIN BUTTON: Ab ye real navigation karega
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginFormScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Log In', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // SIGN UP BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen.withOpacity(0.12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text('Sign Up', style: TextStyle(color: primaryGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSwipePage({
    required String title,
    required String subtitle,
    required String image1,
    required String image2,
    required String image3,
    required bool isSecondPage,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          SizedBox(
            height: 380,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                ClipOval(
                  child: Image.asset(image1, width: 280, height: 280, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 25, right: 40,
                  child: _buildSmallCircleImage(image2, 80),
                ),
                Positioned(
                  left: 30, bottom: 120,
                  child: _buildSmallCircleImage(image3, 70),
                ),
                if (isSecondPage)
                  Positioned(
                    right: 30, bottom: 120,
                    child: _buildSmallCircleImage('assets/images/2nd_Login_Page_Lower_Right_Logo.png', 70),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildSmallCircleImage(String path, double size) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(child: Image.asset(path, width: size, height: size, fit: BoxFit.cover)),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 10),
      height: 10,
      width: _currentPage == index ? 22 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? primaryGreen : Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}