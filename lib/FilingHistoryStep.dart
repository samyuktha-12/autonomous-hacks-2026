import 'package:flutter/material.dart';

class FilingHistoryStep extends StatefulWidget {
  final Map<String, dynamic> previousData;
  final void Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onBack;

  const FilingHistoryStep({
    super.key,
    required this.previousData,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<FilingHistoryStep> createState() => _FilingHistoryStepState();
}

class _FilingHistoryStepState extends State<FilingHistoryStep> {
  String filedBefore = '';
  String lastITRType = '';
  String underAudit = '';
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
    final Color cardColor =const Color.fromARGB(255, 246, 232, 214);

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
                    'Filing History',
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
                  'This helps us pre-fill and guide you better.',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildStepIndicator(currentStep: 3),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildDropdownField(
                      label: 'Have you filed ITR before?',
                      value: filedBefore,
                      options: ['Yes', 'No'],
                      tooltip: 'For carry-forward losses, form guidance',
                      onChanged: (val) => setState(() => filedBefore = val ?? ''),
                      fillColor: cardColor,
                    ),
                    _buildDropdownField(
                      label: 'Last year’s ITR type?',
                      value: lastITRType,
                      options: ['ITR-1', 'ITR-2', 'ITR-3', 'ITR-4', 'Not Sure'],
                      tooltip: 'To prefill info or validate changes',
                      onChanged: (val) => setState(() => lastITRType = val ?? ''),
                      fillColor: cardColor,
                    ),
                    _buildDropdownField(
                      label: 'Are you under tax scrutiny or audit?',
                      value: underAudit,
                      options: ['Yes', 'No'],
                      tooltip: 'Compliance awareness',
                      onChanged: (val) => setState(() => underAudit = val ?? ''),
                      fillColor: cardColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                        final filingData = Map<String, dynamic>.from(widget.previousData);
                      filingData['filedBefore'] = filedBefore;
                      filingData['lastITRType'] = lastITRType;
                      filingData['underAudit'] = underAudit;
                      widget.onSubmit(filingData);
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
                      final filingData = Map<String, dynamic>.from(widget.previousData);
                      filingData['filedBefore'] = filedBefore;
                      filingData['lastITRType'] = lastITRType;
                      filingData['underAudit'] = underAudit;
                      widget.onSubmit(filingData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                    child: const Text(
                      'Submit',
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

  Widget _buildDropdownField({
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
