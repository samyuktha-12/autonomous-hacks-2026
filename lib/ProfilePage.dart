import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'google_sign_in.dart';
import 'home_page.dart';
import 'upload_document.dart';
import 'chat_page.dart';
import 'insights_feed_page.dart';

class ProfilePage extends StatefulWidget {
  final User user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  int _selectedIndex = 3;

  final Color bgColor = const Color.fromARGB(255, 253, 246, 235);
  final Color primaryColor = const Color(0xFFFF6D4D);
  final Color darkPrimaryColor = const Color(0xFFD5451B);
  final Color navColor = const Color.fromARGB(255, 247, 229, 201);
  final Color navHighlight = const Color(0xFFD5451B);
  
  bool showPersonalDetails = false;
  bool showIncomeDetails = false;
  bool showInvestmentDetails = false;
  bool showFilingHistory = false;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();

    if (doc.exists) {
      setState(() {
        profileData = doc.data();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateProfileData(Map<String, dynamic> newData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update(newData);

      fetchProfileData(); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  void _showEditModal() {
    final TextEditingController nameController =
        TextEditingController(text: profileData?['fullName']);
    final TextEditingController mobileController =
        TextEditingController(text: profileData?['mobileNumber']);
    final TextEditingController dobController =
        TextEditingController(text: profileData?['dob']);
    final TextEditingController stateController =
        TextEditingController(text: profileData?['state']);
    final TextEditingController cityController =
        TextEditingController(text: profileData?['city']);
    final TextEditingController panController =
        TextEditingController(text: profileData?['pan']);
    final TextEditingController aadhaarController =
        TextEditingController(text: profileData?['aadhaar']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Edit Personal Details',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  color: Colors.black87)),
            const SizedBox(height: 16),
            _buildTextField("Full Name", nameController),
            _buildTextField("Mobile Number", mobileController),
            _buildTextField("Date of Birth", dobController),
            _buildTextField("State", stateController),
            _buildTextField("City", cityController),
            _buildTextField("PAN", panController),
            _buildTextField("Aadhaar", aadhaarController),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final updatedData = {
                  'fullName': nameController.text,
                  'mobileNumber': mobileController.text,
                  'dob': dobController.text,
                  'state': stateController.text,
                  'city': cityController.text,
                  'pan': panController.text,
                  'aadhaar': aadhaarController.text,
                };
                updateProfileData(updatedData);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!', style: TextStyle(fontFamily: 'Montserrat')),
                    backgroundColor: Color(0xFFFF6D4D),
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              child: const Text("Save",
                  style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, [Color? fillColor, bool isOptional = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        cursorColor: primaryColor,
        style: const TextStyle(
          color: Colors.black87,
          fontFamily: 'Montserrat',
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: isOptional ? "$label (Optional)" : label,
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.black87,
          ),
          filled: true,
          fillColor: fillColor ?? const Color.fromARGB(255, 246, 232, 214),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
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
    setState(() => _selectedIndex = index);
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(user: widget.user),
        ),
      );
    } else if (index == 1) {
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
          builder: (context) => InsightsFeedPage(user: widget.user),
        ),
      );
    } else if (index == 3) {
      // Already on profile page
    }
  }

  Widget _buildProfileDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: Color(0xFF1F1F1F),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14.5,
                color: Color(0xFF6B6B6B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return GestureDetector(
      onTap: () {
        setState(() => showPersonalDetails = !showPersonalDetails);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: darkPrimaryColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 243, 223, 202).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: Color(0xFFD5451B),
                ),
              ),
              title: const Text(
                "Personal Details",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit personal details',
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF6B6B6B), size: 22),
                      onPressed: _showEditModal,
                    ),
                  ),
                  Icon(
                    showPersonalDetails
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF6B6B6B),
                  ),
                ],
              ),
              onTap: () {
                setState(() => showPersonalDetails = !showPersonalDetails);
              },
            ),
            if (showPersonalDetails)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: darkPrimaryColor.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetail("Full Name", profileData?['fullName']),
                    _buildProfileDetail("Mobile", profileData?['mobileNumber']),
                    _buildProfileDetail("DOB", profileData?['dob']),
                    _buildProfileDetail("State", profileData?['state']),
                    _buildProfileDetail("City", profileData?['city']),
                    _buildProfileDetail("PAN", profileData?['pan']),
                    _buildProfileDetail("Aadhaar", profileData?['aadhaar']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeDetailsSection() {
    return GestureDetector(
      onTap: () {
        setState(() => showIncomeDetails = !showIncomeDetails);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: darkPrimaryColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 243, 223, 202).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_outlined,
                  size: 22,
                  color: Color(0xFFD5451B),
                ),
              ),
              title: const Text(
                "Income Details",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit income details',
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF6B6B6B), size: 22),
                      onPressed: () {
                        _showIncomeEditModal();
                      },
                    ),
                  ),
                  Icon(
                    showIncomeDetails
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF6B6B6B),
                  ),
                ],
              ),
              onTap: () {
                setState(() => showIncomeDetails = !showIncomeDetails);
              },
            ),
            if (showIncomeDetails)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: darkPrimaryColor.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetail("Income Type", profileData?['incomeType']),
                    if (profileData?['incomeType'] == "Salaried")
                      _buildProfileDetail("Employer Name", profileData?['employerName']),
                    _buildProfileDetail("Salary", profileData?['salary']),
                    _buildProfileDetail("Salary Type", profileData?['salaryType']),
                    _buildProfileDetail("Other Income", profileData?['otherIncome']),
                    _buildProfileDetail("Owns Business", profileData?['hasBusiness']),
                    _buildProfileDetail("Owns Property", profileData?['hasProperty']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showIncomeEditModal() {
    String incomeType = profileData?['incomeType'] ?? '';
    final TextEditingController employerController =
        TextEditingController(text: profileData?['employerName'] ?? '');
    final TextEditingController salaryController =
        TextEditingController(text: profileData?['salary'] ?? '');
    final TextEditingController otherIncomeController =
        TextEditingController(text: profileData?['otherIncome'] ?? '');
    String ownsBusiness = profileData?['hasBusiness'] ?? '';
    String ownsProperty = profileData?['hasProperty'] ?? '';
    String salaryType = profileData?['salaryType'] ?? 'Monthly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Income Details',
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                // Income Type Dropdown
                _buildDropdownField(
                  "Type of Income",
                  incomeType,
                  const Color.fromARGB(255, 246, 232, 214),
                  ["Salaried", "Freelancer", "Business", "Pension", "Rental"],
                  (value) => setModalState(() => incomeType = value ?? ''),
                ),
                if (incomeType == "Salaried")
                  _buildTextField("Employer Name", employerController, const Color.fromARGB(255, 246, 232, 214), true),
                // Salary Type Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Salary *",
                            style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: "Helps us estimate your taxable income accurately",
                            child: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ToggleButtons(
                        isSelected: [salaryType == 'Monthly', salaryType == 'Annual'],
                        onPressed: (index) {
                          setModalState(() {
                            salaryType = index == 0 ? 'Monthly' : 'Annual';
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: primaryColor,
                        color: Colors.black87,
                        constraints: const BoxConstraints(minHeight: 36, minWidth: 100),
                        children: const [
                          Text("Monthly", style: TextStyle(fontFamily: 'Montserrat')),
                          Text("Annual", style: TextStyle(fontFamily: 'Montserrat')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: salaryController,
                        keyboardType: TextInputType.number,
                        cursorColor: primaryColor,
                        style: const TextStyle(color: Colors.black87, fontFamily: 'Montserrat', fontSize: 15),
                        decoration: InputDecoration(
                          hintText: salaryType == 'Monthly' ? 'e.g. 40000' : 'e.g. 480000',
                          filled: true,
                          fillColor: const Color.fromARGB(255, 246, 232, 214),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTextField("Other Sources of Income", otherIncomeController, const Color.fromARGB(255, 246, 232, 214), true),
                _buildDropdownField(
                  "Do you own a business or startup?",
                  ownsBusiness,
                  const Color.fromARGB(255, 246, 232, 214),
                  ["Yes", "No"],
                  (value) => setModalState(() => ownsBusiness = value ?? ''),
                  isOptional: true,
                ),
                _buildDropdownField(
                  "Do you own property?",
                  ownsProperty,
                  const Color.fromARGB(255, 246, 232, 214),
                  ["Yes", "No"],
                  (value) => setModalState(() => ownsProperty = value ?? ''),
                  isOptional: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final updatedData = {
                      'incomeType': incomeType,
                      'employerName': employerController.text,
                      'salary': salaryController.text,
                      'salaryType': salaryType,
                      'otherIncome': otherIncomeController.text,
                      'hasBusiness': ownsBusiness,
                      'hasProperty': ownsProperty,
                    };
                    updateProfileData(updatedData);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!', style: TextStyle(fontFamily: 'Montserrat')),
                        backgroundColor: Color(0xFFFF6D4D),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text("Save",
                      style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  // Helper for dropdown fields
  Widget _buildDropdownField(
    String label,
    String selectedValue,
    Color fillColor,
    List<String> options,
    void Function(String?) onChanged, {
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: selectedValue.isEmpty ? null : selectedValue,
        items: options.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, color: Colors.black87),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: isOptional ? "$label (Optional)" : "$label *",
          labelStyle: const TextStyle(fontFamily: 'Montserrat', fontSize: 14, color: Colors.black87),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, color: Colors.black87),
      ),
    );
  }

  Widget _buildInvestmentDetailsSection() {
    return GestureDetector(
      onTap: () {
        setState(() => showInvestmentDetails = !showInvestmentDetails);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: darkPrimaryColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 243, 223, 202).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.savings_outlined,
                  size: 22,
                  color: Color(0xFFD5451B),
                ),
              ),
              title: const Text(
                "Investment Details",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit investment details',
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF6B6B6B), size: 22),
                      onPressed: () {
                        _showInvestmentEditModal();
                      },
                    ),
                  ),
                  Icon(
                    showInvestmentDetails
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF6B6B6B),
                  ),
                ],
              ),
              onTap: () {
                setState(() => showInvestmentDetails = !showInvestmentDetails);
              },
            ),
            if (showInvestmentDetails)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: darkPrimaryColor.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetail("Invests under 80C", profileData?['80C'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Pays Health Insurance (80D)", profileData?['80D'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Has Home Loan", profileData?['HomeLoan'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Pays Rent (No HRA)", profileData?['RentNoHRA'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Contributes to NPS", profileData?['NPS'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Has Education Loan", profileData?['EduLoan'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Donates (80G)", profileData?['Donations'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Disability/Dependent", profileData?['Disability'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Has Capital Gains", profileData?['CapitalGains'] == true ? "Yes" : "No"),
                    _buildProfileDetail("Freelance/Contract Work", profileData?['Freelance'] == true ? "Yes" : "No"),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showInvestmentEditModal() {
    // Initialize local state from profileData
    Map<String, bool> investmentOptions = {
      '80C': profileData?['80C'] == true,
      '80D': profileData?['80D'] == true,
      'HomeLoan': profileData?['HomeLoan'] == true,
      'RentNoHRA': profileData?['RentNoHRA'] == true,
      'NPS': profileData?['NPS'] == true,
      'EduLoan': profileData?['EduLoan'] == true,
      'Donations': profileData?['Donations'] == true,
      'Disability': profileData?['Disability'] == true,
      'CapitalGains': profileData?['CapitalGains'] == true,
      'Freelance': profileData?['Freelance'] == true,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Investments & Deductions',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87
                  ),
                ),
                const SizedBox(height: 16),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you invest under 80C?',
                  '80C',
                  'LIC, ELSS, PPF, Home loan principal',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you pay health insurance?',
                  '80D',
                  'For 80D deduction',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you have a home loan?',
                  'HomeLoan',
                  'Principal (80C), Interest (24B or 80EE)',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you pay rent but don’t get HRA?',
                  'RentNoHRA',
                  'HRA or 80GG eligibility',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you contribute to NPS?',
                  'NPS',
                  'Claim additional ₹50K under 80CCD(1B)',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Any education loan?',
                  'EduLoan',
                  '80E deduction',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Any donations?',
                  'Donations',
                  '80G deduction',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Disability or dependent with disability?',
                  'Disability',
                  '80U / 80DD eligibility',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Any capital gains this year?',
                  'CapitalGains',
                  'Stocks, mutual funds, crypto, etc.',
                  investmentOptions,
                ),
                _buildInvestmentCheckbox(
                  setModalState,
                  'Do you do freelance or contract work?',
                  'Freelance',
                  'Presumptive taxation under 44ADA',
                  investmentOptions,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final updatedData = Map<String, dynamic>.from(profileData ?? {});
                    updatedData.addAll(investmentOptions);
                    updateProfileData(updatedData);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!', style: TextStyle(fontFamily: 'Montserrat')),
                        backgroundColor: Color(0xFFFF6D4D),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvestmentCheckbox(
    void Function(void Function()) setModalState,
    String label,
    String key,
    String tooltip,
    Map<String, bool> investmentOptions,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 246, 232, 214),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CheckboxListTile(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Tooltip(
                message: tooltip,
                child: const Icon(Icons.info_outline, size: 18, color: Colors.black45),
              ),
            ],
          ),
          value: investmentOptions[key],
          onChanged: (val) {
            setModalState(() => investmentOptions[key] = val ?? false);
          },
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: primaryColor,
        ),
      ),
    );
  }

  Widget _buildFilingHistorySection() {
    return GestureDetector(
      onTap: () {
        setState(() => showFilingHistory = !showFilingHistory);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: darkPrimaryColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 243, 223, 202).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_edu_outlined,
                  size: 22,
                  color: Color(0xFFD5451B),
                ),
              ),
              title: const Text(
                "Filing History",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit filing history',
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF6B6B6B), size: 22),
                      onPressed: () {
                        _showFilingHistoryEditModal();
                      },
                    ),
                  ),
                  Icon(
                    showFilingHistory
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: const Color(0xFF6B6B6B),
                  ),
                ],
              ),
              onTap: () {
                setState(() => showFilingHistory = !showFilingHistory);
              },
            ),
            if (showFilingHistory)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: darkPrimaryColor.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetail("Filed ITR Before", profileData?['filedBefore']),
                    _buildProfileDetail("Last Year's ITR Type", profileData?['lastITRType']),
                    _buildProfileDetail("Under Audit/Scrutiny", profileData?['underAudit']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilingHistoryEditModal() {
    String filedBefore = profileData?['filedBefore'] ?? '';
    String lastITRType = profileData?['lastITRType'] ?? '';
    String underAudit = profileData?['underAudit'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Filing History',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilingDropdownField(
                  label: 'Have you filed ITR before?',
                  value: filedBefore,
                  options: ['Yes', 'No'],
                  tooltip: 'For carry-forward losses, form guidance',
                  onChanged: (val) => setModalState(() => filedBefore = val ?? ''),
                  fillColor: const Color.fromARGB(255, 246, 232, 214),
                ),
                _buildFilingDropdownField(
                  label: 'Last year’s ITR type?',
                  value: lastITRType,
                  options: ['ITR-1', 'ITR-2', 'ITR-3', 'ITR-4', 'Not Sure'],
                  tooltip: 'To prefill info or validate changes',
                  onChanged: (val) => setModalState(() => lastITRType = val ?? ''),
                  fillColor: const Color.fromARGB(255, 246, 232, 214),
                ),
                _buildFilingDropdownField(
                  label: 'Are you under tax scrutiny or audit?',
                  value: underAudit,
                  options: ['Yes', 'No'],
                  tooltip: 'Compliance awareness',
                  onChanged: (val) => setModalState(() => underAudit = val ?? ''),
                  fillColor: const Color.fromARGB(255, 246, 232, 214),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final updatedData = {
                      'filedBefore': filedBefore,
                      'lastITRType': lastITRType,
                      'underAudit': underAudit,
                    };
                    updateProfileData(updatedData);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!', style: TextStyle(fontFamily: 'Montserrat')),
                        backgroundColor: Color(0xFFFF6D4D),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilingDropdownField({
    required String label,
    required String value,
    required List<String> options,
    required String tooltip,
    required void Function(String?) onChanged,
    required Color fillColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value.isEmpty ? null : value,
        items: options.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.black87,
          ),
          suffixIcon: Tooltip(
            message: tooltip,
            child: const Icon(Icons.info_outline, color: Colors.black45),
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 15,
          color: Colors.black87,
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
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1F1F1F)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
          title: const Text(
            'My Profile',
            style: TextStyle(
              color: Color(0xFF1F1F1F),
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 21,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: darkPrimaryColor.withOpacity(0.2),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: darkPrimaryColor.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: darkPrimaryColor.withOpacity(0.1),
                      backgroundImage: widget.user.photoURL != null && widget.user.photoURL!.isNotEmpty
                          ? NetworkImage(widget.user.photoURL!)
                          : null,
                      child: widget.user.photoURL == null || widget.user.photoURL!.isEmpty
                          ? Text(
                              (profileData?['fullName'] ?? widget.user.email ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: darkPrimaryColor,
                                fontFamily: 'Montserrat',
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profileData?['fullName'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Montserrat',
                      color: Color(0xFF1F1F1F),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.user.email ?? '',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14.5,
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildPersonalDetailsSection(),
                  _buildIncomeDetailsSection(),
                  _buildInvestmentDetailsSection(),
                  _buildFilingHistorySection(),
                  const SizedBox(height: 32),
                  ListTile(
                    leading: const Icon(Icons.logout,
                        color: Color.fromARGB(255, 224, 119, 8)),
                    title: const Text(
                      'Log out',
                      style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Color.fromARGB(255, 224, 119, 8),
                          fontWeight: FontWeight.bold),
                    ),
                    onTap: _signOut,
                  ),
                ],
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
              icon: Icon(_selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_outlined, size: 24),
              activeIcon: Icon(Icons.upload_file_rounded, size: 24),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined, size: 24),
              activeIcon: Icon(Icons.bar_chart_rounded, size: 24),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(_selectedIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
