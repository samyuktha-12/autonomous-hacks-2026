import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'google_sign_in.dart'; 
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  
  FirebaseAuth.instance.setLanguageCode("en");

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,   
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxMate',
      theme: ThemeData.dark(),
      home: const GoogleSignInPage(),  
    );
  }
}