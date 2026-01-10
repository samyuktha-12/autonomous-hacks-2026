import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'google_sign_in.dart';
import 'ProfilePage.dart';
import 'upload_document.dart';
import 'chat_page.dart';
import 'tax_summary_page.dart';
import 'auto_file_page.dart';
import 'insights_feed_page.dart';
import 'itr_guide_page.dart';

class HomePage extends StatefulWidget {
  final User user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color bgColor = const Color.fromARGB(255, 253, 246, 235);
  final Color primaryColor = const Color(0xFFFF6D4D);
  final Color darkPrimaryColor = const Color(0xFFD5451B);
  final Color textColor = const Color(0xFFA86523);
  final Color searchBoxColor = const Color.fromARGB(255, 252, 239, 224);
  final Color cardColor = const Color.fromARGB(255, 250, 233, 215);
  final Color navColor = const Color.fromARGB(255, 247, 229, 201);
  int _selectedIndex = 0;

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GoogleSignInPage()),
    );
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadDocumentsPage(user: widget.user),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(user: widget.user),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(user: widget.user),
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? additionalText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color.fromARGB(50, 213, 69, 27),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: darkPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: const Color(0xFF1F1F1F).withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Montserrat',
                      color: Color(0xFF1F1F1F),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Montserrat',
                      color: const Color(0xFF1F1F1F).withOpacity(0.75),
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (additionalText != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        additionalText,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Montserrat',
                          color: darkPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF1F1F1F)),
              onPressed: () {},
              tooltip: 'Menu',
            ),
          ),
          centerTitle: true,
          title: const Text(
            'Home',
            style: TextStyle(
              color: Color(0xFF1F1F1F),
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFF1F1F1F)),
                onPressed: _signOut,
                tooltip: 'Logout',
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Section
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi ${widget.user.displayName?.split(' ').first ?? 'User'}!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontFamily: 'Montserrat',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeGreeting,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F1F1F),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  cursorColor: primaryColor,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Color(0xFF1F1F1F),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search documents, forms, or guides...',
                    hintStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      color: const Color(0xFF1F1F1F).withOpacity(0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: const Color(0xFF1F1F1F).withOpacity(0.5),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      darkPrimaryColor,
                      primaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome!',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Let\'s get started with your taxes.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.95),
                              fontFamily: 'Montserrat',
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Image.asset(
                      'assets/images/welcome.png',
                      height: 75,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Insights Feed Banner
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InsightsFeedPage(user: widget.user),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: Color(0xFFD5451B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Live Tax Insights',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Montserrat',
                                  color: Color(0xFF1F1F1F),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Get real-time opportunities, risks & deadlines',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF1F1F1F).withOpacity(0.7),
                                  fontFamily: 'Montserrat',
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: const Color(0xFF1F1F1F).withOpacity(0.4),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Dashboard Section Header
              const Text(
                'Your Tax Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1F1F1F),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Dashboard Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.75,
                children: [
                  _buildDashboardCard(
                    icon: Icons.upload_file_rounded,
                    title: 'Uploaded Docs',
                    subtitle: 'View Form 16, slips & documents',
                    additionalText: 'Manage files',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UploadDocumentsPage(user: widget.user),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Tax Summary',
                    subtitle: 'View your tax estimate & breakdown',
                    additionalText: 'See analysis',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaxSummaryPage(user: widget.user),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Auto-File ITR',
                    subtitle: 'Smart filing assistant & automation',
                    additionalText: 'Quick file',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AutoFilePage(user: widget.user),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'ITR Guide',
                    subtitle: 'Forms, checklist & filing steps',
                    additionalText: 'Learn more',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItrGuidePage(user: widget.user),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: darkPrimaryColor,
          unselectedItemColor: const Color(0xFF1F1F1F).withOpacity(0.6),
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                size: 24,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.upload_file_outlined,
                size: 24,
              ),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 24,
              ),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person_outline_rounded,
                size: 24,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}