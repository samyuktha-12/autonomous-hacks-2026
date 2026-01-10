import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class SuccessPage extends StatelessWidget {
  final User user;

  const SuccessPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        // Background image
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/success_bg.png"),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Centered content just below the brown dot
        Align(
          alignment: Alignment(0, 0.6), // Adjust this Y value to move up/down
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Your Account Set",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You have successfully\nset up the account",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black54,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 26),
              GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage(user: user)),
                    (route) => false,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6E6E), Color(0xFFFF4D4D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Text(
                    "Continue to Home",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
  }
}
