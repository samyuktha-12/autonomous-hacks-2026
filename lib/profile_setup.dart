import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ProfileDetailsStep.dart';
import 'IncomeDetailsStep.dart';
import 'InvestmentDetailsStep.dart';
import 'FilingHistoryStep.dart';
import 'SuccessPage.dart';

class ProfileSetupPage extends StatefulWidget {
  final User user;

  const ProfileSetupPage({super.key, required this.user});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _opacity = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFFFEF3E2);
    final Color primaryColor = const Color(0xFFFF6D4D);
    final String displayName = widget.user.displayName ?? 'User';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min, // only take space needed
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Intro
                  const Text(
                    'Let’s get started',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We’ll help you set up your profile\nand personalize your experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontFamily: 'Montserrat',
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Profile Image + Welcome
                  CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        const AssetImage('assets/images/profile.png'),
                    backgroundColor: Colors.transparent,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(198, 94, 29, 1),
                      fontFamily: 'Montserrat',
                    ),
                  ),

                  const SizedBox(height: 36),

                  // CTA Button
                  ElevatedButton(
                    onPressed: () async {
                      final formData =
                          await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileDetailsStep(
                            onNext: (formData) {
                              Navigator.pop(context, formData);
                            },
                            onBack: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );

                      if (formData != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncomeDetailsStep(
                              formData: formData,
                              onNext: (incomeData) {
                                final combinedData = {
                                  ...formData,
                                  ...incomeData,
                                };

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvestmentDetailsStep(
                                      previousData: combinedData,
                                      onNext: (finalData) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FilingHistoryStep(
                                              previousData: finalData,
                                              onSubmit:
                                                  (finalMergedData) async {
                                                print(
                                                    "🎯 Final Collected Data:");
                                                print(finalMergedData);

                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(widget.user.uid)
                                                      .set(
                                                          finalMergedData,
                                                          SetOptions(
                                                              merge:
                                                                  true)); // merge to retain previous fields

                                                  Navigator.pushAndRemoveUntil(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            SuccessPage(
                                                                user: widget
                                                                    .user)),
                                                    (route) => false,
                                                  );
                                                } catch (e) {
                                                  print(
                                                      "❌ Error saving profile data: $e");

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Failed to save your profile. Please try again.'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              onBack: () {
                                                Navigator.pop(
                                                    context); // Back to InvestmentDetailsStep
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                      onBack: () {
                                        Navigator.pop(
                                            context); // ✅ Back to IncomeDetailsStep
                                      },
                                    ),
                                  ),
                                );
                              },
                              onBack: () {
                                Navigator.pop(
                                    context); // ✅ Back to ProfileDetailsStep
                              },
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Start Setup',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
