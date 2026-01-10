import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IncomeDetailsStep extends StatefulWidget {
  final Map<String, dynamic> formData;
  final void Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const IncomeDetailsStep({
    super.key,
    required this.formData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<IncomeDetailsStep> createState() => _IncomeDetailsStepState();
}

class _IncomeDetailsStepState extends State<IncomeDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  String incomeType = '';
  final employerController = TextEditingController();
  final salaryController = TextEditingController();
  final otherIncomeController = TextEditingController();
  String ownsBusiness = '';
  String ownsProperty = '';
  String salaryType = 'Monthly';

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
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black,),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Income Details',
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
                  'This helps us understand your tax profile better.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildStepIndicator(currentStep: 1),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      _buildDropdownField(
                        "Type of Income",
                        incomeType,
                        cardColor,
                        ["Salaried", "Freelancer", "Business", "Pension", "Rental"],
                        (value) => setState(() => incomeType = value ?? ''),
                      ),
                      if (incomeType == "Salaried")
                        _buildTextField("Employer Name", employerController, cardColor, isOptional: true),
                      _buildSalaryField(cardColor),
                      _buildTextField("Other Sources of Income", otherIncomeController, cardColor, isOptional: true),
                      _buildDropdownField(
                        "Do you own a business or startup?",
                        ownsBusiness,
                        cardColor,
                        ["Yes", "No"],
                        (value) => setState(() => ownsBusiness = value ?? ''),
                        isOptional: true,
                      ),
                      _buildDropdownField(
                        "Do you own property?",
                        ownsProperty,
                        cardColor,
                        ["Yes", "No"],
                        (value) => setState(() => ownsProperty = value ?? ''),
                        isOptional: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() && incomeType.isNotEmpty) {
                    final Map<String, dynamic> incomeData = {
                      'incomeType': incomeType,
                      'employerName': employerController.text,
                      'salary': salaryController.text,
                      'salaryType': salaryType,
                      'otherIncome': otherIncomeController.text,
                      'hasBusiness': ownsBusiness,
                      'hasProperty': ownsProperty,
                    };
                    widget.onNext(incomeData);
                  } else if (incomeType.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select your income type")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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

  Widget _buildSalaryField(Color fillColor) {
    return Padding(
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
              setState(() {
                salaryType = index == 0 ? 'Monthly' : 'Annual';
              });
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: const Color(0xFFFF6D4D),
            color: Colors.black87,
            constraints: const BoxConstraints(minHeight: 36, minWidth: 100),
            children: const [
              Text("Monthly", style: TextStyle(fontFamily: 'Montserrat')),
              Text("Annual", style: TextStyle(fontFamily: 'Montserrat')),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: salaryController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            cursorColor: Colors.black87,
            style: const TextStyle(color: Colors.black87, fontFamily: 'Montserrat', fontSize: 15),
            decoration: InputDecoration(
              hintText: salaryType == 'Monthly' ? 'e.g. 40000' : 'e.g. 480000',
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your salary';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color fillColor, {
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: Colors.black87,
        style: const TextStyle(color: Colors.black87, fontFamily: 'Montserrat', fontSize: 15),
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
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

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
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
        dropdownColor: Colors.white,
        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, color: Colors.black87),
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
