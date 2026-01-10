import 'package:flutter/material.dart';

class InvestmentDetailsStep extends StatefulWidget {
  final Map<String, dynamic> previousData;
  final void Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const InvestmentDetailsStep({
    super.key,
    required this.previousData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<InvestmentDetailsStep> createState() => _InvestmentDetailsStepState();
}

class _InvestmentDetailsStepState extends State<InvestmentDetailsStep> {
  final Map<String, bool> investmentOptions = {
    '80C': false,
    '80D': false,
    'HomeLoan': false,
    'RentNoHRA': false,
    'NPS': false,
    'EduLoan': false,
    'Donations': false,
    'Disability': false,
    'CapitalGains': false,
    'Freelance': false,
  };

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
                    'Investments & Deductions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'These help us maximize your tax deductions.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildStepIndicator(currentStep: 2),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildCheckbox(
                        'Do you invest under 80C?', '80C',
                        tooltip: 'LIC, ELSS, PPF, Home loan principal'),
                    _buildCheckbox(
                        'Do you pay health insurance?', '80D',
                        tooltip: 'For 80D deduction'),
                    _buildCheckbox('Do you have a home loan?', 'HomeLoan',
                        tooltip: 'Principal (80C), Interest (24B or 80EE)'),
                    _buildCheckbox(
                        'Do you pay rent but don’t get HRA?', 'RentNoHRA',
                        tooltip: 'HRA or 80GG eligibility'),
                    _buildCheckbox('Do you contribute to NPS?', 'NPS',
                        tooltip: 'Claim additional ₹50K under 80CCD(1B)'),
                    _buildCheckbox('Any education loan?', 'EduLoan',
                        tooltip: '80E deduction'),
                    _buildCheckbox('Any donations?', 'Donations',
                        tooltip: '80G deduction'),
                    _buildCheckbox(
                        'Disability or dependent with disability?', 'Disability',
                        tooltip: '80U / 80DD eligibility'),
                    _buildCheckbox('Any capital gains this year?', 'CapitalGains',
                        tooltip: 'Stocks, mutual funds, crypto, etc.'),
                    _buildCheckbox(
                        'Do you do freelance or contract work?', 'Freelance',
                        tooltip: 'Presumptive taxation under 44ADA'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      widget.onNext(widget.previousData);
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final investmentData = Map<String, dynamic>.from(widget.previousData);
                      investmentData.addAll(investmentOptions);
                      widget.onNext(investmentData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, String key, {required String tooltip}) {
    final Color cardColor = const Color.fromARGB(255, 246, 232, 214);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
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
            setState(() => investmentOptions[key] = val ?? false);
          },
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFFFF6D4D),
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
