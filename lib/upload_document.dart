import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'chat_page.dart';
import 'pdf_viewer_page.dart';
import 'home_page.dart';
import 'ProfilePage.dart';

class UploadDocumentsPage extends StatefulWidget {
  final User user;

  const UploadDocumentsPage({super.key, required this.user});

  @override
  State<UploadDocumentsPage> createState() => _UploadDocumentsPageState();
}

class _UploadDocumentsPageState extends State<UploadDocumentsPage> {
  final Color bgColor = const Color.fromARGB(255, 253, 246, 235);
  final Color primaryColor = const Color(0xFFFF6D4D);
  final Color darkPrimaryColor = const Color(0xFFD5451B);
  final Color textColor = const Color(0xFFA86523);

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _employerController = TextEditingController();
  final TextEditingController _financialYearController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _investmentTypeController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _lenderController = TextEditingController();
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _landlordPanController = TextEditingController();
  final TextEditingController _assetTypeController = TextEditingController();
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _trustNameController = TextEditingController();
  final TextEditingController _deductionRateController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _illnessController = TextEditingController();
  final TextEditingController _studentController = TextEditingController();

  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilterType = 'All';
  String _selectedFilterYear = 'All';

  String _selectedType = '';
  bool _isUploading = false;
  bool _showUploadForm = false;

  final List<String> _docTypes = [
    "salary_slip",
    "form_16",
    "form_26as",
    "bank_interest_certificate",
    "investment_proof",
    "home_loan_statement",
    "rent_receipt",
    "capital_gains",
    "donation_receipt",
    "medical_bill",
    "education_loan",
  ];

  final Map<String, String> _docTypeDisplayNames = {
    "salary_slip": "Salary Slip",
    "form_16": "Form 16",
    "form_26as": "Form 26AS/AIS",
    "bank_interest_certificate": "Bank Interest Certificate",
    "investment_proof": "Investment Proof",
    "home_loan_statement": "Home Loan Statement",
    "rent_receipt": "Rent Receipt/Agreement",
    "capital_gains": "Capital Gains Statement",
    "donation_receipt": "Donation Receipt",
    "medical_bill": "Medical Bill",
    "education_loan": "Education Loan Certificate",
  };

  final List<String> _filterTypes = [
    'All',
    'Salary Slip',
    'Form 16',
    'Form 26AS/AIS',
    'Bank Interest Certificate',
    'Investment Proof',
    'Home Loan Statement',
    'Rent Receipt/Agreement',
    'Capital Gains Statement',
    'Donation Receipt',
    'Medical Bill',
    'Education Loan Certificate',
  ];

  final List<String> _filterYears = [
    'All',
    '2024',
    '2023',
    '2022',
    '2021',
    '2020',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildDropdownField(
    String label,
    String selectedValue,
    List<String> options,
    void Function(String?) onChanged, {
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "$label *",
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: const Color(0xFF1F1F1F).withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedValue.isEmpty ? null : selectedValue,
            items: options.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFF1F1F1F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF1F1F1F).withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD5451B), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF1F1F1F).withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Color(0xFF1F1F1F),
              fontWeight: FontWeight.w500,
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFD5451B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_selectedType) {
      case "salary_slip":
        return Column(
          children: [
            _buildTextField("Month", _monthController, tooltip: "Enter the month (e.g., January, February)"),
            _buildTextField("Year", _yearController, keyboardType: TextInputType.number, tooltip: "Enter the year (e.g., 2024)"),
            _buildTextField("Employer Name (Optional)", _employerController, isOptional: true),
          ],
        );
      case "form_16":
        return Column(
          children: [
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
            _buildDropdownField("Source", _sourceController.text, ["Employer", "Bank", "Other"], (val) {
              setState(() => _sourceController.text = val ?? '');
            }, tooltip: "Who issued this Form 16?"),
            if (_sourceController.text == "Other")
              _buildTextField("Other Source", _noteController, isOptional: true),
          ],
        );
      case "form_26as":
        return _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25");
      case "bank_interest_certificate":
        return Column(
          children: [
            _buildTextField("Bank Name", _bankNameController),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      case "investment_proof":
        return Column(
          children: [
            _buildTextField("Investment Type", _investmentTypeController, tooltip: "e.g., ELSS, PPF, LIC"),
            _buildTextField("Section Code", _sectionController, tooltip: "e.g., 80C, 80D, 80CCD"),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      case "home_loan_statement":
        return Column(
          children: [
            _buildTextField("Lender Name", _lenderController),
            _buildDropdownField("Loan Component", _componentController.text, ["Principal", "Interest"], (val) {
              setState(() => _componentController.text = val ?? '');
            }, tooltip: "Principal for 80C, Interest for 24B"),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      case "rent_receipt":
        return Column(
          children: [
            _buildTextField("Period (e.g. Apr 2023 - Mar 2024)", _periodController),
            _buildTextField("Landlord PAN (Optional)", _landlordPanController, isOptional: true),
          ],
        );
      case "capital_gains":
        return Column(
          children: [
            _buildDropdownField("Asset Type", _assetTypeController.text, ["Equity", "Mutual Fund", "Crypto"], (val) {
              setState(() => _assetTypeController.text = val ?? '');
            }),
            _buildTextField("Broker Name", _brokerController),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      case "donation_receipt":
        return Column(
          children: [
            _buildTextField("Trust Name", _trustNameController),
            _buildDropdownField("Deduction Rate", _deductionRateController.text, ["50%", "100%"], (val) {
              setState(() => _deductionRateController.text = val ?? '');
            }, tooltip: "50% for most trusts, 100% for specific organizations"),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      case "medical_bill":
        return Column(
          children: [
            _buildTextField("Patient Relation", _relationController, tooltip: "e.g., Self, Spouse, Parent"),
            _buildTextField("Nature of Illness (Optional)", _illnessController, isOptional: true),
          ],
        );
      case "education_loan":
        return Column(
          children: [
            _buildTextField("Lender Name", _lenderController),
            _buildTextField("Student Name", _studentController),
            _buildTextField("Financial Year", _financialYearController, tooltip: "Format: 2024-25"),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isOptional ? "$label (Optional)" : "$label *",
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: const Color(0xFF1F1F1F).withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            cursorColor: darkPrimaryColor,
            style: const TextStyle(
              color: Color(0xFF1F1F1F),
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF1F1F1F).withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD5451B), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF1F1F1F).withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildMetadata() {
    Map<String, dynamic> metadata = {};
    
    switch (_selectedType) {
      case "salary_slip":
        metadata = {
          "month": _monthController.text,
          "year": _yearController.text,
          "employer": _employerController.text,
        };
        break;
      case "form_16":
        metadata = {
          "financial_year": _financialYearController.text,
          "source": _sourceController.text,
        };
        break;
      case "form_26as":
        metadata = {
          "financial_year": _financialYearController.text,
        };
        break;
      case "bank_interest_certificate":
        metadata = {
          "bank_name": _bankNameController.text,
          "financial_year": _financialYearController.text,
        };
        break;
      case "investment_proof":
        metadata = {
          "investment_type": _investmentTypeController.text,
          "section": _sectionController.text,
          "financial_year": _financialYearController.text,
        };
        break;
      case "home_loan_statement":
        metadata = {
          "lender": _lenderController.text,
          "component": _componentController.text,
          "financial_year": _financialYearController.text,
        };
        break;
      case "rent_receipt":
        metadata = {
          "period": _periodController.text,
          "landlord_pan": _landlordPanController.text,
        };
        break;
      case "capital_gains":
        metadata = {
          "asset_type": _assetTypeController.text,
          "broker": _brokerController.text,
          "financial_year": _financialYearController.text,
        };
        break;
      case "donation_receipt":
        metadata = {
          "trust_name": _trustNameController.text,
          "deduction_rate": _deductionRateController.text,
          "financial_year": _financialYearController.text,
        };
        break;
      case "medical_bill":
        metadata = {
          "relation": _relationController.text,
          "illness": _illnessController.text,
        };
        break;
      case "education_loan":
        metadata = {
          "lender": _lenderController.text,
          "student": _studentController.text,
          "financial_year": _financialYearController.text,
        };
        break;
    }
    
    return metadata;
  }

  Future<void> _pickAndUploadFile() async {
    if (!mounted) return;
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      if (_selectedType.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select document type')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isUploading = true);

      try {
        debugPrint('Starting upload for user: ${widget.user.uid}');
        debugPrint('Document type: $_selectedType');
        debugPrint('File name: $fileName');
        
        // Prepare metadata
        Map<String, dynamic> metadata = _buildMetadata();
        debugPrint('Metadata: $metadata');
        
        // Create multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConfig.uploadDocumentEndpoint),
        );

        // Add form fields
        request.fields['user_id'] = widget.user.uid;
        request.fields['document_type'] = _selectedType;
        request.fields['metadata'] = jsonEncode(metadata);

        // Add file
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: fileName,
          ),
        );

        debugPrint('Sending request to: ${ApiConfig.uploadDocumentEndpoint}');
        
        // Send request with timeout
        var response = await request.send().timeout(const Duration(seconds: 30));
        var responseData = await response.stream.bytesToString();
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: $responseData');
        
        var jsonResponse = jsonDecode(responseData);

        if (response.statusCode == 200) {
          // Success - show AI processing results
          if (!mounted) return;
          _showUploadSuccessDialog(jsonResponse);
          
          _clearAllControllers();
          if (!mounted) return;
          setState(() {
            _showUploadForm = false;
            _selectedType = '';
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Document uploaded and processed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(jsonResponse['detail'] ?? 'Upload failed');
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _showUploadSuccessDialog(Map<String, dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Upload Successful!',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Document ID: ${response['document_id']}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: const Color(0xFF1F1F1F).withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Extracted Information:',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              ...(response['extracted_metadata'] as Map<String, dynamic>).entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFD5451B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${entry.key.replaceAll('_', ' ').toUpperCase()}: ${entry.value}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            color: Color(0xFF1F1F1F),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Processing Accuracy: ${(response['confidence_score'] * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (response['validation_errors'] != null && (response['validation_errors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Validation Issues:',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(response['validation_errors'] as List).map((error) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $error',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (response['suggestions'] != null && (response['suggestions'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Suggestions:',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w700,
                              color: Colors.blue,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(response['suggestions'] as List).map((suggestion) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $suggestion',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Color(0xFFD5451B),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to clear all controllers
  void _clearAllControllers() {
    _monthController.clear();
    _yearController.clear();
    _employerController.clear();
    _financialYearController.clear();
    _sourceController.clear();
    _bankNameController.clear();
    _investmentTypeController.clear();
    _sectionController.clear();
    _lenderController.clear();
    _componentController.clear();
    _periodController.clear();
    _landlordPanController.clear();
    _assetTypeController.clear();
    _brokerController.clear();
    _trustNameController.clear();
    _deductionRateController.clear();
    _relationController.clear();
    _illnessController.clear();
    _studentController.clear();
  }

  List<MapEntry<String, dynamic>> _getDisplayMetadata(Map<String, dynamic> metadata) {
    final displayFields = <MapEntry<String, dynamic>>[];
    
    // Priority fields to display first
    final priorityFields = ['employer', 'month', 'year', 'financial_year', 'bank_name', 'lender'];
    
    // Add priority fields first
    for (final field in priorityFields) {
      if (metadata.containsKey(field) && metadata[field] != null && metadata[field].toString().isNotEmpty) {
        displayFields.add(MapEntry(field, metadata[field]));
      }
    }
    
    // Add other fields (excluding system fields)
    for (final entry in metadata.entries) {
      if (!priorityFields.contains(entry.key) && 
          !['fileName', 'url', 'type', 'timestamp', 'file_url'].contains(entry.key) &&
          entry.value != null && 
          entry.value.toString().isNotEmpty) {
        displayFields.add(entry);
      }
    }
    
    // Return first 3 fields
    return displayFields.take(3).toList();
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    final url = doc['file_url'];
    if (url != null && url is String && url.isNotEmpty) {
      try {
        final fileName = doc['metadata']?['fileName'] ?? doc['file_name'] ?? 'Document';
        
        // Navigate to PDF viewer page
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(
              pdfUrl: url,
              title: fileName,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error opening document: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File URL not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDocument(String docId, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Document',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$fileName"? This action cannot be undone.',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFF1F1F1F),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: const Color(0xFF1F1F1F).withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await http.delete(
          Uri.parse(ApiConfig.getDeleteDocumentEndpoint(widget.user.uid, docId)),
        );

        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Document deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Refresh the list
        } else {
          throw Exception('Delete failed');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editDocument(String docId, Map<String, dynamic> data) async {
    // Pre-fill controllers with existing data
    _selectedType = data['document_type'] ?? '';
    // Ensure the selected type is valid
    if (!_docTypes.contains(_selectedType)) {
      _selectedType = '';
    }
    _monthController.text = data['metadata']?['month'] ?? '';
    _yearController.text = data['metadata']?['year'] ?? '';
    _employerController.text = data['metadata']?['employer'] ?? '';
    _financialYearController.text = data['metadata']?['financial_year'] ?? '';
    _sourceController.text = data['metadata']?['source'] ?? '';
    _bankNameController.text = data['metadata']?['bank_name'] ?? '';
    _investmentTypeController.text = data['metadata']?['investment_type'] ?? '';
    _sectionController.text = data['metadata']?['section'] ?? '';
    _lenderController.text = data['metadata']?['lender'] ?? '';
    _componentController.text = data['metadata']?['component'] ?? '';
    _periodController.text = data['metadata']?['period'] ?? '';
    _landlordPanController.text = data['metadata']?['landlord_pan'] ?? '';
    _assetTypeController.text = data['metadata']?['asset_type'] ?? '';
    _brokerController.text = data['metadata']?['broker'] ?? '';
    _trustNameController.text = data['metadata']?['trust_name'] ?? '';
    _deductionRateController.text = data['metadata']?['deduction_rate'] ?? '';
    _relationController.text = data['metadata']?['relation'] ?? '';
    _illnessController.text = data['metadata']?['illness'] ?? '';
    _studentController.text = data['metadata']?['student'] ?? '';

    setState(() {
      _showUploadForm = true;
    });

    // Scroll to upload form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F).withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              cursorColor: darkPrimaryColor,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Color(0xFF1F1F1F),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search documents...',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Filter dropdowns
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  "Filter by Type",
                  _selectedFilterType,
                  _filterTypes,
                  (val) => setState(() => _selectedFilterType = val ?? 'All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  "Filter by Year",
                  _selectedFilterYear,
                  _filterYears,
                  (val) => setState(() => _selectedFilterYear = val ?? 'All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadForm() {
    if (!_showUploadForm) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1F1F1F).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Color(0xFFD5451B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Upload New Document',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
              Tooltip(
                message: 'Close upload form',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF1F1F1F)),
                  onPressed: () {
                    setState(() {
                      _showUploadForm = false;
                      _selectedType = '';
                      _clearAllControllers();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            "Document Type",
            _selectedType.isEmpty ? '' : _docTypeDisplayNames[_selectedType] ?? _selectedType,
            _docTypes.map((type) => _docTypeDisplayNames[type] ?? type).toList(),
            (val) {
              final selectedType = _docTypeDisplayNames.entries
                  .firstWhere((entry) => entry.value == val, orElse: () => MapEntry('', ''))
                  .key;
              setState(() => _selectedType = selectedType);
            },
            tooltip: 'Select the type of tax document you are uploading',
          ),
          if (_selectedType.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTypeSpecificFields(),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadFile,
              icon: _isUploading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: Text(
                _isUploading ? 'Processing Document...' : 'Upload & Process Document',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDocuments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6D4D)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading documents...',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: const Color(0xFF1F1F1F).withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading documents',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      color: const Color(0xFF1F1F1F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: const Color(0xFF1F1F1F).withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data ?? [];
        
        // Apply filters
        List<Map<String, dynamic>> filteredDocs = docs.where((doc) {
          final type = doc['document_type'] ?? '';
          final fileName = doc['metadata']?['fileName'] ?? '';
          final searchTerm = _searchController.text.toLowerCase();
          
          // Search filter
          if (searchTerm.isNotEmpty && !fileName.toLowerCase().contains(searchTerm)) {
            return false;
          }
          
          // Type filter
          if (_selectedFilterType != 'All') {
            final displayName = _docTypeDisplayNames[type] ?? type;
            if (displayName != _selectedFilterType) {
              return false;
            }
          }
          
          // Year filter
          if (_selectedFilterYear != 'All') {
            final year = doc['metadata']?['year'] ?? doc['metadata']?['financial_year'] ?? '';
            if (year.toString() != _selectedFilterYear) {
              return false;
            }
          }
          
          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          // Check if it's due to filters or no documents at all
          final hasSearchFilter = _searchController.text.isNotEmpty;
          final hasTypeFilter = _selectedFilterType != 'All';
          final hasYearFilter = _selectedFilterYear != 'All';
          final hasAnyFilter = hasSearchFilter || hasTypeFilter || hasYearFilter;
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F).withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasAnyFilter ? Icons.filter_list_rounded : Icons.folder_open_rounded,
                      size: 48,
                      color: const Color(0xFF1F1F1F).withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasAnyFilter ? 'No documents match your filters' : 'No documents found',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 17,
                      color: const Color(0xFF1F1F1F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAnyFilter 
                      ? 'Try adjusting your search or filters'
                      : 'Upload your first document to get started',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: const Color(0xFF1F1F1F).withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (hasAnyFilter) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _selectedFilterType = 'All';
                          _selectedFilterYear = 'All';
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text(
                        'Clear Filters',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final fileName = doc['metadata']?['fileName'] ?? doc['file_name'] ?? 'Document';
            final documentType = doc['document_type'] ?? '';
            final uploadDate = doc['uploaded_at'] ?? '';
            final metadata = doc['metadata'] as Map<String, dynamic>? ?? {};
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1F1F1F).withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openDocument(doc),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description_rounded,
                                color: Color(0xFFD5451B),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Document',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F1F1F),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _docTypeDisplayNames[documentType] ?? documentType,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 11,
                                        color: Color(0xFFD5451B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1F1F1F), size: 20),
                              color: Colors.white,
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'open':
                                    _openDocument(doc);
                                    break;
                                  case 'edit':
                                    _editDocument(doc['id'], doc);
                                    break;
                                  case 'delete':
                                    _deleteDocument(doc['id'], fileName);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.open_in_new_rounded, color: Color(0xFF1F1F1F), size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Open',
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          color: Color(0xFF1F1F1F),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_rounded, color: Color(0xFFD5451B), size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Edit',
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          color: Color(0xFF1F1F1F),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Delete',
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          color: Color(0xFF1F1F1F),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._getDisplayMetadata(metadata).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD5451B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${e.key.replaceAll("_", " ").toUpperCase()}: ${e.value}',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: const Color(0xFF1F1F1F).withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDocuments() async {
    try {
      debugPrint('Fetching documents for user: ${widget.user.uid}');
      debugPrint('API URL: ${ApiConfig.getUserDocumentsEndpoint(widget.user.uid)}');
      debugPrint('Base URL: ${ApiConfig.baseUrl}');
      
      // First, try to check server health
      try {
        final healthResponse = await http.get(
          Uri.parse(ApiConfig.healthCheckEndpoint),
        ).timeout(const Duration(seconds: 5));
        debugPrint('Health check status: ${healthResponse.statusCode}');
      } catch (healthError) {
        debugPrint('Health check failed: $healthError');
        // Continue anyway, might be a network issue
      }
      
      final response = await http.get(
        Uri.parse(ApiConfig.getUserDocumentsEndpoint(widget.user.uid)),
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = List<Map<String, dynamic>>.from(data['documents'] ?? []);
        debugPrint('Fetched ${documents.length} documents');
        return documents;
      } else if (response.statusCode == 404) {
        // No documents found - return empty list instead of throwing error
        debugPrint('No documents found (404)');
        return [];
      } else {
        throw Exception('Failed to fetch documents: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      debugPrint('Error type: ${e.runtimeType}');
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception('Cannot connect to server at ${ApiConfig.baseUrl}. Please check:\n1. Server is running on port 8000\n2. Android emulator can access 10.0.2.2:8000\n3. Firewall is not blocking the connection');
      }
      throw Exception('Error: $e');
    }
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
          iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F1F1F)),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          title: const Text(
            'Upload Documents',
            style: TextStyle(
              color: Color(0xFF1F1F1F),
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: [
            Tooltip(
              message: 'Refresh documents',
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1F1F1F)),
                onPressed: () {
                  setState(() {
                    // This will trigger a rebuild and refetch documents
                  });
                },
              ),
            ),
            Tooltip(
              message: _showUploadForm ? 'Hide upload form' : 'Add new document',
              child: IconButton(
                icon: Icon(
                  _showUploadForm ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                  color: const Color(0xFFD5451B),
                ),
                onPressed: () {
                  setState(() {
                    _showUploadForm = !_showUploadForm;
                    if (!_showUploadForm) {
                      _selectedType = '';
                      _clearAllControllers();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndFilters(),
            _buildUploadForm(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Documents',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFF1F1F1F),
                  ),
                ),
                Tooltip(
                  message: _showUploadForm ? 'Hide upload form' : 'Show upload form',
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showUploadForm = !_showUploadForm;
                        if (!_showUploadForm) {
                          _selectedType = '';
                          _clearAllControllers();
                        }
                      });
                    },
                    icon: Icon(
                      _showUploadForm ? Icons.remove_rounded : Icons.add_rounded,
                      color: darkPrimaryColor,
                      size: 18,
                    ),
                    label: Text(
                      _showUploadForm ? 'Hide Upload' : 'Add Document',
                      style: const TextStyle(
                        color: Color(0xFFD5451B),
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDocumentList(),
            const SizedBox(height: 20),
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
          currentIndex: 1, // Upload tab index
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(user: widget.user),
                ),
              );
            } else if (index == 1) {
              // Already on upload page, do nothing
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
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file_outlined, size: 24),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 24),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}