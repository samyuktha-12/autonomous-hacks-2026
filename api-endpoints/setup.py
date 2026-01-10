#!/usr/bin/env python3
"""
Setup script for TaxMate Document Upload API
This script helps configure the environment and install dependencies
"""

import os
import sys
import subprocess
import json
from pathlib import Path

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 8):
        print("❌ Python 3.8 or higher is required")
        sys.exit(1)
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} detected")

def install_dependencies():
    """Install required dependencies"""
    print("\n📦 Installing dependencies...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ Dependencies installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error installing dependencies: {e}")
        sys.exit(1)

def create_env_file():
    """Create .env file with required environment variables"""
    env_file = Path(".env")
    
    if env_file.exists():
        print("⚠️  .env file already exists")
        response = input("Do you want to overwrite it? (y/N): ")
        if response.lower() != 'y':
            print("Skipping .env file creation")
            return
    
    print("\n🔧 Creating .env file...")
    
    env_content = """# TaxMate Document Upload API Environment Variables

# Firebase Configuration
FIREBASE_BUCKET=your-firebase-bucket-name

# Google Gemini AI
GEMINI_API_KEY=your-gemini-api-key

# Google Cloud Vision (optional for image processing)
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json

# Server Configuration
HOST=0.0.0.0
PORT=8000
"""
    
    with open(env_file, 'w') as f:
        f.write(env_content)
    
    print("✅ .env file created")
    print("⚠️  Please update the .env file with your actual credentials")

def check_service_account():
    """Check if service account file exists"""
    service_account_file = Path("service-account.json")
    
    if not service_account_file.exists():
        print("\n⚠️  service-account.json not found")
        print("Please download your Firebase service account JSON file and place it in the api-endpoints directory")
        print("You can download it from: https://console.firebase.google.com/project/_/settings/serviceaccounts/adminsdk")
    else:
        print("✅ service-account.json found")

def create_sample_pdfs():
    """Create sample PDF files for testing"""
    print("\n📄 Creating sample PDF files...")
    try:
        subprocess.check_call([sys.executable, "create_sample_pdfs.py"])
        print("✅ Sample PDF files created")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error creating sample PDFs: {e}")
        print("You can create them manually by running: python create_sample_pdfs.py")

def test_server():
    """Test if the server can start"""
    print("\n🧪 Testing server startup...")
    try:
        # Import the server module to check for syntax errors
        import server
        print("✅ Server module imports successfully")
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("Please check your dependencies installation")
    except Exception as e:
        print(f"❌ Error: {e}")

def print_next_steps():
    """Print next steps for the user"""
    print("\n" + "=" * 50)
    print("🎉 Setup completed!")
    print("=" * 50)
    print("\nNext steps:")
    print("1. Update the .env file with your actual credentials:")
    print("   - FIREBASE_BUCKET: Your Firebase Storage bucket name")
    print("   - GEMINI_API_KEY: Your Google Gemini API key")
    print("   - GOOGLE_APPLICATION_CREDENTIALS: Path to your service account JSON")
    print("\n2. Ensure you have the service-account.json file in this directory")
    print("\n3. Start the server:")
    print("   python server.py")
    print("\n4. Test the API:")
    print("   python test_document_upload.py")
    print("\n5. View API documentation:")
    print("   http://localhost:8000/docs")
    print("\nFor more information, see README_DOCUMENT_UPLOAD.md")

def main():
    """Main setup function"""
    print("🚀 TaxMate Document Upload API Setup")
    print("=" * 50)
    
    # Check Python version
    check_python_version()
    
    # Install dependencies
    install_dependencies()
    
    # Create .env file
    create_env_file()
    
    # Check service account
    check_service_account()
    
    # Create sample PDFs
    create_sample_pdfs()
    
    # Test server
    test_server()
    
    # Print next steps
    print_next_steps()

if __name__ == "__main__":
    main() 