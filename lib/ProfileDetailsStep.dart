import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfileDetailsStep extends StatefulWidget {
  final void Function(Map<String, dynamic> data) onNext;
  final VoidCallback onBack;

  const ProfileDetailsStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<ProfileDetailsStep> createState() => _ProfileDetailsStepState();
}

class _ProfileDetailsStepState extends State<ProfileDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final dobController = TextEditingController();
  final cityController = TextEditingController();
  final panController = TextEditingController();
  final aadhaarController = TextEditingController();

  String selectedState = '';
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFFFEF3E2);
    final Color primaryColor = const Color(0xFFFF6D4D);
    final Color cardColor = const Color.fromARGB(255, 246, 232, 214);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: widget.onBack,
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Let’s get started',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'We’ll collect a few details to personalize your experience.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildStepIndicator(currentStep: 0),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _buildTextField("Full Name", nameController, cardColor),
                      _buildTextField(
                        "Mobile Number",
                        mobileController,
                        cardColor,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildDatePickerField(
                          "Date of Birth", dobController, cardColor),
                      _buildDropdownField("State", selectedState, cardColor,
                          (newValue) {
                        setState(() {
                          selectedState = newValue!;
                        });
                      }),
                      _buildTextField("City", cityController, cardColor),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildTextField("PAN Number", panController, cardColor,
                          isOptional: true),
                      _buildTextField(
                          "Aadhaar Number", aadhaarController, cardColor,
                          isOptional: true, isObscure: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      selectedState.isNotEmpty) {
                    final formData = {
                      'fullName': nameController.text.trim(),
                      'mobileNumber': mobileController.text.trim(),
                      'dob': dobController.text.trim(),
                      'state': selectedState,
                      'city': cityController.text.trim(),
                      'pan': panController.text.trim(),
                      'aadhaar': aadhaarController.text.trim(),
                    };
                    widget.onNext(formData);
                  } else if (selectedState.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select your state")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color fillColor, {
    bool isOptional = false,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        cursorColor: Colors.black87,
        style: const TextStyle(
          color: Colors.black87,
          fontFamily: 'Montserrat',
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: isOptional ? "$label (Optional)" : "$label *",
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.black87,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePickerField(
      String label, TextEditingController controller, Color fillColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.light().copyWith(
                  primaryColor: const Color(0xFFFF6D4D),
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFFF6D4D),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (pickedDate != null) {
            setState(() {
              controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
            });
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: controller,
            cursorColor: Colors.black87,
            style: const TextStyle(
              color: Colors.black87,
              fontFamily: 'Montserrat',
              fontSize: 15,
            ),
            decoration: InputDecoration(
              labelText: "$label *",
              labelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.black87,
              ),
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String selectedValue,
    Color fillColor,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: selectedValue.isEmpty ? null : selectedValue,
        items: _indianStates.map((state) {
          return DropdownMenuItem<String>(
            value: state,
            child: Text(
              state,
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
          labelText: "$label *",
          labelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.black87,
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStepIndicator({required int currentStep}) {
    final Color primaryColor = const Color(0xFFFF6D4D);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: index == currentStep ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == currentStep ? primaryColor : Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ✅ Full list of Indian States and Union Territories
const List<String> _indianStates = [
  "Andhra Pradesh",
  "Arunachal Pradesh",
  "Assam",
  "Bihar",
  "Chhattisgarh",
  "Goa",
  "Gujarat",
  "Haryana",
  "Himachal Pradesh",
  "Jharkhand",
  "Karnataka",
  "Kerala",
  "Madhya Pradesh",
  "Maharashtra",
  "Manipur",
  "Meghalaya",
  "Mizoram",
  "Nagaland",
  "Odisha",
  "Punjab",
  "Rajasthan",
  "Sikkim",
  "Tamil Nadu",
  "Telangana",
  "Tripura",
  "Uttar Pradesh",
  "Uttarakhand",
  "West Bengal",
  "Andaman and Nicobar Islands",
  "Chandigarh",
  "Dadra and Nagar Haveli and Daman and Diu",
  "Delhi",
  "Jammu and Kashmir",
  "Ladakh",
  "Lakshadweep",
  "Puducherry",
];
