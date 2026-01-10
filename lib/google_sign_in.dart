import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_page.dart';
import 'profile_setup.dart';

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});

  @override
  _GoogleSignInPageState createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

Future<void> _signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      final String userId = user.uid;
      final DocumentReference profileRef = _firestore
          .collection('users')
          .doc(userId);

      final DocumentSnapshot profileDoc = await profileRef.get();

      // If no profile document → create it with base data
      if (!profileDoc.exists) {
        await profileRef.set({
          'username': user.displayName ?? 'Unknown',
          'profilePicture': user.photoURL ?? '',
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // First-time user → go to profile setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfileSetupPage(user: user)),
        );
        return;
      }

      // ✅ Profile exists → check if required fields are complete
      final data = profileDoc.data() as Map<String, dynamic>;
      final isProfileComplete = data.containsKey('fullName') &&
          data.containsKey('dob') &&
          data.containsKey('incomeType');

      if (isProfileComplete) {
        // 🚀 Profile is complete → Go to Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: user)),
        );
      } else {
        // 🧩 Profile incomplete → Go to Profile Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProfileSetupPage(user: user)),
        );
      }
    }
  } catch (e) {
    print("❌ Error during Google Sign-In: $e");
  }
}

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/taxmate-bg.png',
            fit: BoxFit.cover,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Manage your taxes\nseamlessly',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(198, 94, 29, 1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Let TaxMate help you organize your finances,\nreceipts, and tax filings in one place.',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: GestureDetector(
                        onTap: _signInWithGoogle,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6E6E), // Light coral red
                                Color(0xFFFF4D4D), // Deeper red
                              ],
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          child: const Center(
                            child: Text(
                              'START SAVING',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                        height: 60), // To give breathing room from bottom
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
