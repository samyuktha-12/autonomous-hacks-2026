# TaxMate - AI-Powered Tax Assistant

A comprehensive Flutter application for managing Indian tax filing with AI-powered document processing, tax insights, and automated ITR filing assistance.

## 🚀 Features

- **User Authentication**: Google Sign-In integration
- **Document Management**: Upload and manage tax-related documents (Form 16, Salary Slips, Form 26AS, etc.)
- **AI-Powered Assistant**: Google Gemini AI for intelligent tax advice and document processing
- **Tax Summary & Insights**: Comprehensive tax calculations and personalized insights
- **Auto-File ITR**: Automated ITR draft generation and preview
- **CA Finder**: Location-based search for nearby Chartered Accountants
- **Tax Deadlines**: Calendar integration for important tax deadlines
- **Professional UI**: Clean, modern, and accessible interface

## 📱 Tech Stack

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Firebase**: Authentication, Firestore, and Storage
- **Material Design**: Modern UI components

### Backend
- **FastAPI**: Python web framework
- **Google Gemini AI**: Document processing and chat assistant
- **Google Cloud Vision**: OCR and text extraction
- **Google Places API**: Location services

## 🏗️ Architecture

```
Flutter App → FastAPI Server → Google AI Services → Firebase
```

## 📋 Document Types Supported

- Salary Slips
- Form 16
- Form 26AS
- Bank Interest Certificates
- Investment Proofs (80C, 80D, etc.)
- Home Loan Statements
- Rent Receipts
- Capital Gains Documents
- Donation Receipts
- Medical Bills
- Education Loan Certificates

## 🔧 Setup

### Prerequisites
- Flutter SDK
- Python 3.10+
- Firebase project
- Google Cloud project with Gemini API enabled

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd taxmate
```

2. Install Flutter dependencies
```bash
flutter pub get
```

3. Set up backend (see `api-endpoints/` directory)
```bash
cd api-endpoints
pip install -r requirements.txt
```

4. Configure environment variables
- Create `.env` file in `api-endpoints/` with:
  - `GEMINI_API_KEY=your-api-key`
  - `FIREBASE_BUCKET=your-bucket-name`
  - `GOOGLE_PLACES_API_KEY=your-places-api-key`

5. Run the app
```bash
flutter run
```