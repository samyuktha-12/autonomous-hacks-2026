import os
import uuid
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Query, Body
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, firestore, storage
import google.generativeai as genai
from datetime import datetime, timedelta
from dotenv import load_dotenv
import re
import json
import io
from typing import Optional, Dict, Any, List
from google.cloud import vision
import base64
from pydantic import BaseModel
import fitz  # PyMuPDF for PDF processing
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
import requests
from math import radians, sin, cos, sqrt, atan2
import asyncio

# Load environment variables from .env
load_dotenv()

app = FastAPI()

# Add CORS middleware to allow Flutter app to make requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Firebase setup
FIREBASE_BUCKET = os.getenv("FIREBASE_BUCKET")
if not firebase_admin._apps:
    # Priority order:
    # 1. SERVICE_ACCOUNT_JSON_B64 (for explicit service account in cloud)
    # 2. service-account.json file (for local development)
    # 3. Application Default Credentials (for GCP services like Cloud Run with default service account)
    SERVICE_ACCOUNT_JSON_B64 = os.getenv("SERVICE_ACCOUNT_JSON_B64")
    if SERVICE_ACCOUNT_JSON_B64:
        # Decode from base64 (for cloud platforms)
        try:
            service_account_json = json.loads(base64.b64decode(SERVICE_ACCOUNT_JSON_B64).decode('utf-8'))
            cred = credentials.Certificate(service_account_json)
            firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_BUCKET})
        except Exception as e:
            raise ValueError(f"Failed to decode SERVICE_ACCOUNT_JSON_B64: {str(e)}")
    else:
        # Try to load from file (for local development)
        SERVICE_ACCOUNT_JSON = os.path.join(os.path.dirname(__file__), "service-account.json")
        if os.path.exists(SERVICE_ACCOUNT_JSON):
            cred = credentials.Certificate(SERVICE_ACCOUNT_JSON)
            firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_BUCKET})
        else:
            # Use Application Default Credentials (for GCP Cloud Run, App Engine, etc.)
            # This works when running on GCP with default service account
            try:
                firebase_admin.initialize_app(options={"storageBucket": FIREBASE_BUCKET})
            except Exception as e:
                raise ValueError(
                    f"Firebase initialization failed. "
                    f"Either provide service-account.json file or set SERVICE_ACCOUNT_JSON_B64. "
                    f"Error: {str(e)}"
                )
db = firestore.client()
bucket = storage.bucket()

# Gemini setup
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        print(f"✅ Gemini API configured (key length: {len(GEMINI_API_KEY)} chars)")
    except Exception as e:
        print(f"⚠️  Warning: Failed to configure Gemini API: {e}")
else:
    print("⚠️  Warning: GEMINI_API_KEY not set. AI features will use fallback mode.")

# Google Cloud Vision setup
vision_client = vision.ImageAnnotatorClient()

# Google Places API setup
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "")
PLACES_API_BASE_URL = "https://maps.googleapis.com/maps/api/place"

# Document type configurations
DOCUMENT_TYPES = {
    "salary_slip": {
        "required_fields": ["month", "year", "employer"],
        "optional_fields": ["employee_id", "gross_salary", "net_salary", "tds"]
    },
    "form_16": {
        "required_fields": ["financial_year", "source"],
        "optional_fields": ["employer_name", "employee_id", "total_income", "tds"]
    },
    "form_26as": {
        "required_fields": ["financial_year"],
        "optional_fields": ["pan", "total_income", "total_tds"]
    },
    "bank_interest_certificate": {
        "required_fields": ["bank_name", "financial_year"],
        "optional_fields": ["account_number", "interest_amount", "account_type"]
    },
    "investment_proof": {
        "required_fields": ["investment_type", "section", "financial_year"],
        "optional_fields": ["amount", "institution", "policy_number"]
    },
    "home_loan_statement": {
        "required_fields": ["lender", "component", "financial_year"],
        "optional_fields": ["loan_account_number", "amount", "property_address"]
    },
    "rent_receipt": {
        "required_fields": ["period"],
        "optional_fields": ["landlord_pan", "monthly_rent", "property_address"]
    },
    "capital_gains": {
        "required_fields": ["asset_type", "broker", "financial_year"],
        "optional_fields": ["gains_amount", "transaction_type", "asset_name"]
    },
    "donation_receipt": {
        "required_fields": ["trust_name", "deduction_rate", "financial_year"],
        "optional_fields": ["amount", "trust_pan", "donation_type"]
    },
    "medical_bill": {
        "required_fields": ["relation", "section"],
        "optional_fields": ["patient_name", "hospital", "amount", "illness_type"]
    },
    "education_loan": {
        "required_fields": ["lender", "student", "financial_year"],
        "optional_fields": ["loan_account_number", "interest_amount", "institution"]
    }
}

class DocumentUploadRequest(BaseModel):
    user_id: str
    document_type: str
    metadata: Dict[str, Any] = {}

class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: Optional[Dict[str, Any]] = {}

def convert_firestore_datetime_to_iso(obj: Any) -> Any:
    """Recursively convert Firestore datetime and Timestamp objects to ISO format strings"""
    # Handle Firestore Timestamp objects
    if hasattr(obj, 'timestamp') and hasattr(obj, 'seconds'):
        # This is likely a Firestore Timestamp object
        try:
            # Convert to datetime and then to ISO format
            dt = obj.to_datetime() if hasattr(obj, 'to_datetime') else datetime.fromtimestamp(obj.timestamp())
            return dt.isoformat()
        except Exception:
            # If conversion fails, try to get seconds and convert
            try:
                dt = datetime.fromtimestamp(obj.seconds)
                return dt.isoformat()
            except Exception:
                return str(obj)
    # Handle Python datetime objects
    elif isinstance(obj, datetime):
        return obj.isoformat()
    elif isinstance(obj, dict):
        return {key: convert_firestore_datetime_to_iso(value) for key, value in obj.items()}
    elif isinstance(obj, list):
        return [convert_firestore_datetime_to_iso(item) for item in obj]
    else:
        return obj

async def extract_text_from_pdf(pdf_content: bytes) -> str:
    """Extract text from PDF using PyMuPDF"""
    try:
        doc = fitz.open(stream=pdf_content, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()
        doc.close()
        return text
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing PDF: {str(e)}")

async def extract_text_from_image(image_content: bytes) -> str:
    """Extract text from image using Google Cloud Vision API"""
    try:
        image = vision.Image(content=image_content)
        response = vision_client.text_detection(image=image)
        
        if response.error.message:
            raise Exception(response.error.message)
        
        texts = response.text_annotations
        if texts:
            return texts[0].description
        return ""
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing image: {str(e)}")

async def extract_metadata_fallback(document_type: str, extracted_text: str, user_metadata: Dict[str, Any]) -> Dict[str, Any]:
    """Fallback metadata extraction when Gemini API is unavailable"""
    # Use user-provided metadata as base
    extracted_metadata = user_metadata.copy()
    
    # Add filename if available
    if 'fileName' not in extracted_metadata and 'file_name' in user_metadata:
        extracted_metadata['fileName'] = user_metadata.get('file_name')
    
    # Basic validation
    required_fields = DOCUMENT_TYPES.get(document_type, {}).get('required_fields', [])
    validation_errors = []
    
    for field in required_fields:
        if field not in extracted_metadata or not extracted_metadata[field]:
            validation_errors.append(f"Missing required field: {field}")
    
    return {
        "extracted_metadata": extracted_metadata,
        "confidence_score": 0.5,  # Lower confidence for fallback
        "validation_errors": validation_errors,
        "suggestions": ["AI extraction unavailable. Using provided metadata only."]
    }

async def process_document_with_gemini(document_type: str, extracted_text: str, user_metadata: Dict[str, Any]) -> Dict[str, Any]:
    """Use Gemini AI to extract and sanitize document information"""
    
    # Check if Gemini API key is configured
    if not GEMINI_API_KEY:
        print("Warning: GEMINI_API_KEY not set. Using fallback extraction.")
        return await extract_metadata_fallback(document_type, extracted_text, user_metadata)
    
    prompt = f"""
    You are a tax document processing expert. Analyze the following document text and extract relevant information for a {document_type} document.
    
    Document Type: {document_type}
    User Provided Metadata: {json.dumps(user_metadata, indent=2)}
    
    Document Text:
    {extracted_text[:5000]}  # Limit text to avoid token limits
    
    Required fields for {document_type}: {DOCUMENT_TYPES[document_type]['required_fields']}
    Optional fields for {document_type}: {DOCUMENT_TYPES[document_type]['optional_fields']}
    
    Please extract and return a JSON object with the following structure:
    {{
        "extracted_metadata": {{
            // All extracted fields with their values
        }},
        "confidence_score": 0.95, // Confidence in extraction (0-1)
        "validation_errors": [], // Any validation issues found
        "suggestions": [] // Any suggestions for missing or unclear data
    }}
    
    Important guidelines:
    1. Extract dates in YYYY-MM-DD format where possible
    2. Extract amounts as numbers only (no currency symbols)
    3. Standardize month names to full names (January, February, etc.)
    4. For financial years, use format "YYYY-YY" (e.g., "2023-24")
    5. Validate PAN numbers (10 characters, alphanumeric)
    6. Ensure all required fields are present
    """
    
    try:
        # Configure generation config
        generation_config = {
            "temperature": 0.1,
            "max_output_tokens": 2048,
        }
        
        model = genai.GenerativeModel('gemini-2.0-flash', generation_config=generation_config)
        
        # Try to generate content - run in thread pool with timeout
        try:
            # Run the synchronous Gemini call in a thread pool with timeout
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=30.0  # 30 second timeout
            )
        except asyncio.TimeoutError:
            print("Warning: Gemini API call timed out after 30 seconds. Using fallback extraction.")
            return await extract_metadata_fallback(document_type, extracted_text, user_metadata)
        except Exception as api_error:
            error_str = str(api_error)
            # Check for DNS or network errors
            if "DNS" in error_str or "503" in error_str or "timeout" in error_str.lower() or "network" in error_str.lower() or "resolution failed" in error_str.lower():
                print(f"Warning: Gemini API network error: {error_str}. Using fallback extraction.")
                return await extract_metadata_fallback(document_type, extracted_text, user_metadata)
            else:
                # Re-raise if it's a different type of error
                raise
        
        # Parse the response to extract JSON
        response_text = response.text
        json_start = response_text.find('{')
        json_end = response_text.rfind('}') + 1
        
        if json_start != -1 and json_end != 0:
            json_str = response_text[json_start:json_end]
            result = json.loads(json_str)
            return result
        else:
            print("Warning: Could not parse Gemini response as JSON. Using fallback extraction.")
            return await extract_metadata_fallback(document_type, extracted_text, user_metadata)
            
    except HTTPException:
        raise
    except Exception as e:
        error_str = str(e)
        print(f"Error calling Gemini API: {error_str}")
        # For any other errors, use fallback
        if "DNS" in error_str or "503" in error_str or "timeout" in error_str.lower() or "network" in error_str.lower():
            return await extract_metadata_fallback(document_type, extracted_text, user_metadata)
        else:
            # For other errors, still try fallback but log the error
            print(f"Using fallback extraction due to error: {error_str}")
            return await extract_metadata_fallback(document_type, extracted_text, user_metadata)

async def upload_file_to_firebase(file_content: bytes, file_name: str, user_id: str) -> str:
    """Upload file to Firebase Storage and return download URL"""
    try:
        # Create a unique file path
        file_extension = file_name.split('.')[-1]
        unique_filename = f"{user_id}/{uuid.uuid4()}.{file_extension}"
        
        # Upload to Firebase Storage
        blob = bucket.blob(unique_filename)
        blob.upload_from_string(file_content, content_type=f'application/{file_extension}')
        
        # Make the blob publicly readable (or implement signed URLs for security)
        blob.make_public()
        
        return blob.public_url
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error uploading file: {str(e)}")

async def store_document_metadata(user_id: str, document_type: str, file_url: str, 
                                extracted_metadata: Dict[str, Any], user_metadata: Dict[str, Any]) -> str:
    """Store document metadata in Firestore"""
    try:
        # Combine user metadata with extracted metadata
        combined_metadata = {**user_metadata, **extracted_metadata}
        
        # Add system fields
        document_data = {
            "user_id": user_id,
            "document_type": document_type,
            "file_url": file_url,
            "uploaded_at": datetime.utcnow(),
            "status": "processed",
            "metadata": combined_metadata,
            "version": "1.0"
        }
        
        # Store in Firestore
        doc_ref = db.collection('users').document(user_id).collection('documents').add(document_data)
        
        return doc_ref[1].id
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error storing metadata: {str(e)}")

async def process_chat_with_gemini(user_message: str, context: Dict[str, Any]) -> Dict[str, Any]:
    """Process chat message with Gemini AI and return response with action chips and follow-ups"""
    
    # Build context string from user's documents and profile
    context_str = ""
    if context:
        if 'documents' in context and context['documents']:
            context_str += "\n\nUser's Documents:\n"
            for doc in context['documents'][:5]:  # Limit to 5 most recent documents
                doc_type = doc.get('document_type', 'Unknown')
                metadata = doc.get('metadata', {})
                context_str += f"• {doc_type}: {', '.join([f'{k}={v}' for k, v in list(metadata.items())[:3]])}\n"
        
        if 'user_profile' in context:
            profile = context['user_profile']
            context_str += f"\nUser Profile: {profile}\n"
    
    prompt = f"""
    You are a helpful tax assistant for an Indian tax filing application. The user is asking about tax-related questions.
    
    Context Information:
    {context_str}
    
    User Question: {user_message}
    
    Please provide a helpful, accurate, and concise response. Focus on:
    1. Direct answers to the user's question
    2. Relevant tax information for India
    3. Practical advice when applicable
    4. Clear explanations without unnecessary jargon
    
    Keep your response focused and to the point. Avoid very long explanations unless specifically requested.
    
    After your response, suggest 2-4 relevant follow-up questions that the user might want to ask next.
    Also suggest 2-4 action chips (quick actions) that would be helpful based on the conversation.
    
    Format your response as JSON with:
    {{
        "response": "your main response text",
        "follow_up_questions": ["question 1", "question 2", "question 3"],
        "action_chips": [
            {{"label": "Action name", "type": "action_type", "data": {{}}}},
            ...
        ]
    }}
    
    Action types can be:
    - "find_ca": Find nearby Chartered Accountants
    - "view_deadlines": View tax deadlines
    - "upload_document": Upload a document
    - "calculate_tax": Calculate tax
    - "view_summary": View tax summary
    - "chat": Continue conversation with a specific question
    
    Only include relevant actions based on the conversation context.
    """
    
    try:
        # Check if Gemini API key is configured
        if not GEMINI_API_KEY:
            return {
                "response": "I'm sorry, but the AI assistant is currently unavailable. Please try again later or contact support.",
                "follow_up_questions": [
                    "What documents do I need to file my ITR?",
                    "What are the tax deduction options available?",
                    "When is the ITR filing deadline?"
                ],
                "action_chips": []
            }
        
        model = genai.GenerativeModel('gemini-2.0-flash')
        
        # Try to generate content with timeout
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=30.0  # 30 second timeout
            )
            response_text = response.text
        except asyncio.TimeoutError:
            return {
                "response": "I'm sorry, but the request timed out. Please try again with a shorter question.",
                "follow_up_questions": [
                    "What documents do I need to file my ITR?",
                    "What are the tax deduction options available?"
                ],
                "action_chips": []
            }
        except Exception as api_error:
            error_str = str(api_error)
            if "DNS" in error_str or "503" in error_str or "timeout" in error_str.lower() or "network" in error_str.lower() or "resolution failed" in error_str.lower():
                return {
                    "response": "I'm sorry, but I'm having trouble connecting to the AI service. Please check your internet connection and try again later.",
                    "follow_up_questions": [
                        "What documents do I need to file my ITR?",
                        "What are the tax deduction options available?"
                    ],
                    "action_chips": []
                }
            else:
                raise
        
        # Try to parse JSON response
        try:
            # Extract JSON from markdown code blocks if present
            json_match = re.search(r'```json\s*(\{.*?\})\s*```', response_text, re.DOTALL)
            if json_match:
                response_text = json_match.group(1)
            else:
                # Try to find JSON object directly
                json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if json_match:
                    response_text = json_match.group(0)
            
            parsed = json.loads(response_text)
            return parsed
        except:
            # If JSON parsing fails, return as plain text with defaults
            return {
                "response": response_text,
                "follow_up_questions": [
                    "What documents do I need to file my ITR?",
                    "What are the tax deduction options available?",
                    "When is the ITR filing deadline?"
                ],
                "action_chips": []
            }
    except HTTPException:
        raise
    except Exception as e:
        # Return a user-friendly error instead of crashing
        return {
            "response": f"I apologize, but I encountered an error processing your request. Please try again later. Error: {str(e)[:100]}",
            "follow_up_questions": [
                "What documents do I need to file my ITR?",
                "What are the tax deduction options available?"
            ],
            "action_chips": []
        }

async def sanitize_chat_response(raw_response: str) -> str:
    """Sanitize and format chat response into bullet points"""
    
    prompt = f"""
    You are a response formatting expert. Take the following tax-related response and format it into clear, concise bullet points.
    
    Raw Response:
    {raw_response}
    
    Please:
    1. Convert the response into bullet points (•)
    2. Keep each bullet point concise (1-2 lines max)
    3. Remove any unnecessary repetition
    4. Maintain the key information and accuracy
    5. Use clear, simple language
    6. Limit to 5-8 bullet points maximum
    7. If the response is already very short, just clean it up without forcing bullet points
    
    Return only the formatted response, no additional text.
    """
    
    try:
        # Check if Gemini API key is configured
        if not GEMINI_API_KEY:
            return raw_response
        
        model = genai.GenerativeModel('gemini-2.0-flash')
        
        # Try to generate content with timeout
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(model.generate_content, prompt),
                timeout=15.0  # 15 second timeout for sanitization
            )
            return response.text.strip()
        except (asyncio.TimeoutError, Exception) as e:
            error_str = str(e)
            # If sanitization fails (timeout, DNS, network error), return the original response
            if "DNS" in error_str or "503" in error_str or "timeout" in error_str.lower() or "network" in error_str.lower() or "resolution failed" in error_str.lower():
                print(f"Warning: Chat response sanitization failed: {error_str}. Returning original response.")
            return raw_response
    except Exception as e:
        # If sanitization fails for any reason, return the original response
        return raw_response

@app.post("/upload-document")
async def upload_document(
    user_id: str = Form(...),
    document_type: str = Form(...),
    file: UploadFile = File(...),
    metadata: str = Form("{}")  # JSON string of additional metadata
):
    """
    Upload and process tax documents with AI-powered extraction
    """
    try:
        # Validate document type
        if document_type not in DOCUMENT_TYPES:
            raise HTTPException(status_code=400, detail=f"Invalid document type. Allowed types: {list(DOCUMENT_TYPES.keys())}")
        
        # Validate file type
        if not file.filename.lower().endswith('.pdf'):
            raise HTTPException(status_code=400, detail="Only PDF files are supported")
        
        # Parse user metadata
        try:
            user_metadata = json.loads(metadata) if metadata else {}
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="Invalid metadata JSON format")
        
        # Read file content
        file_content = await file.read()
        
        # Extract text from PDF
        extracted_text = await extract_text_from_pdf(file_content)
        
        if not extracted_text.strip():
            raise HTTPException(status_code=400, detail="Could not extract text from PDF. Please ensure the document is readable.")
        
        # Process with Gemini AI
        ai_result = await process_document_with_gemini(document_type, extracted_text, user_metadata)
        
        # Upload file to Firebase Storage
        file_url = await upload_file_to_firebase(file_content, file.filename, user_id)
        
        # Store metadata in Firestore
        document_id = await store_document_metadata(
            user_id, 
            document_type, 
            file_url, 
            ai_result.get("extracted_metadata", {}), 
            user_metadata
        )
        
        return {
            "success": True,
            "document_id": document_id,
            "file_url": file_url,
            "extracted_metadata": ai_result.get("extracted_metadata", {}),
            "confidence_score": ai_result.get("confidence_score", 0),
            "validation_errors": ai_result.get("validation_errors", []),
            "suggestions": ai_result.get("suggestions", [])
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

@app.get("/documents/{user_id}")
async def get_user_documents(user_id: str, document_type: Optional[str] = None):
    """Get all documents for a user, optionally filtered by type"""
    try:
        # Build base query
        query = db.collection('users').document(user_id).collection('documents')
        
        if document_type:
            query = query.where('document_type', '==', document_type)
        
        # Fetch documents - try with ordering first, fallback to no ordering if it fails
        documents = []
        try:
            # Try to fetch with ordering
            docs = query.order_by('uploaded_at', direction=firestore.Query.DESCENDING).stream()
            for doc in docs:
                try:
                    doc_data = doc.to_dict()
                    if doc_data:  # Ensure doc_data is not None
                        doc_data['id'] = doc.id
                        # Convert Firestore datetime objects to ISO format strings for JSON serialization
                        doc_data = convert_firestore_datetime_to_iso(doc_data)
                        documents.append(doc_data)
                except Exception as doc_error:
                    print(f"Warning: Error processing document {doc.id}: {doc_error}")
                    import traceback
                    traceback.print_exc()
                    continue
        except Exception as order_error:
            # If ordering fails (e.g., no index, empty collection, or index not created), fetch without ordering
            print(f"Warning: Could not order by uploaded_at: {order_error}. Fetching without order.")
            try:
                docs = query.stream()
                for doc in docs:
                    try:
                        doc_data = doc.to_dict()
                        if doc_data:  # Ensure doc_data is not None
                            doc_data['id'] = doc.id
                            # Convert Firestore datetime objects to ISO format strings for JSON serialization
                            doc_data = convert_firestore_datetime_to_iso(doc_data)
                            documents.append(doc_data)
                    except Exception as doc_error:
                        print(f"Warning: Error processing document {doc.id}: {doc_error}")
                        import traceback
                        traceback.print_exc()
                        continue
                
                # Sort in Python if we have documents
                if documents:
                    documents.sort(key=lambda x: x.get('uploaded_at', ''), reverse=True)
            except Exception as fetch_error:
                print(f"Error fetching documents without order: {fetch_error}")
                import traceback
                traceback.print_exc()
                # Return empty list instead of crashing
                documents = []
        
        # Verify the response is JSON serializable
        try:
            json.dumps({"success": True, "documents": documents, "count": len(documents)})
        except (TypeError, ValueError) as json_error:
            print(f"Warning: Response contains non-serializable data: {json_error}")
            # Try to fix by converting again
            documents = [convert_firestore_datetime_to_iso(doc) for doc in documents]
        
        return {
            "success": True,
            "documents": documents,
            "count": len(documents)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in get_user_documents: {str(e)}")
        import traceback
        traceback.print_exc()
        # Return empty list instead of crashing - this allows the app to continue working
        return {
            "success": True,
            "documents": [],
            "count": 0,
            "error": f"Error fetching documents: {str(e)}"
        }

@app.get("/health")
async def health_check():
    """Health check endpoint to verify server is running"""
    return {
        "status": "healthy",
        "message": "Server is running"
    }

@app.get("/document-types")
async def get_document_types():
    """Get all supported document types and their field requirements"""
    return {
        "success": True,
        "document_types": DOCUMENT_TYPES
    }

@app.delete("/documents/{user_id}/{document_id}")
async def delete_document(user_id: str, document_id: str):
    """Delete a document and its associated file"""
    try:
        # Get document reference
        doc_ref = db.collection('users').document(user_id).collection('documents').document(document_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Document not found")
        
        doc_data = doc.to_dict()
        file_url = doc_data.get('file_url')
        
        # Delete from Firebase Storage
        if file_url:
            try:
                # Extract blob name from URL
                blob_name = file_url.split(f"{FIREBASE_BUCKET}/")[-1]
                blob = bucket.blob(blob_name)
                blob.delete()
            except Exception as e:
                print(f"Warning: Could not delete file from storage: {e}")
        
        # Delete from Firestore
        doc_ref.delete()
        
        return {
            "success": True,
            "message": "Document deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting document: {str(e)}")

@app.post("/chat")
async def chat_with_assistant(request: ChatRequest):
    """Chat with the tax assistant using Gemini AI"""
    try:
        # Get user's documents for context
        user_documents = []
        try:
            docs_query = db.collection('users').document(request.user_id).collection('documents')
            docs = docs_query.order_by('uploaded_at', direction=firestore.Query.DESCENDING).limit(5).stream()
            
            for doc in docs:
                doc_data = doc.to_dict()
                doc_data['id'] = doc.id
                user_documents.append(doc_data)
        except Exception as e:
            print(f"Warning: Could not fetch user documents for context: {e}")
        
        # Build context
        context = {
            "documents": user_documents,
            "user_profile": request.context.get("user_profile", {})
        }
        
        # Process with Gemini AI
        ai_response = await process_chat_with_gemini(request.message, context)
        
        # Extract response components
        main_response = ai_response.get("response", "")
        follow_up_questions = ai_response.get("follow_up_questions", [])
        action_chips = ai_response.get("action_chips", [])
        
        # Sanitize and format main response
        formatted_response = await sanitize_chat_response(main_response)
        
        # Store chat history (optional)
        try:
            chat_data = {
                "user_id": request.user_id,
                "message": request.message,
                "response": formatted_response,
                "timestamp": datetime.utcnow(),
                "context_used": bool(user_documents)
            }
            db.collection('users').document(request.user_id).collection('chat_history').add(chat_data)
        except Exception as e:
            print(f"Warning: Could not store chat history: {e}")
        
        return {
            "success": True,
            "response": formatted_response,
            "follow_up_questions": follow_up_questions[:4],  # Limit to 4
            "action_chips": action_chips[:4],  # Limit to 4
            "context_used": bool(user_documents),
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing chat: {str(e)}")

@app.get("/chat-history/{user_id}")
async def get_chat_history(user_id: str, limit: int = Query(10, ge=1, le=50)):
    """Get user's chat history"""
    try:
        query = db.collection('users').document(user_id).collection('chat_history')
        docs = query.order_by('timestamp', direction=firestore.Query.DESCENDING).limit(limit).stream()
        
        chat_history = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            # Convert Firestore datetime objects to ISO format strings for JSON serialization
            doc_data = convert_firestore_datetime_to_iso(doc_data)
            chat_history.append(doc_data)
        
        return {
            "success": True,
            "chat_history": chat_history,
            "count": len(chat_history)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching chat history: {str(e)}")

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two coordinates in kilometers using Haversine formula"""
    R = 6371  # Earth radius in kilometers
    
    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)
    
    a = sin(delta_lat / 2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    
    return R * c

@app.get("/places/nearby-ca")
async def find_nearby_ca(
    latitude: float = Query(..., description="User's latitude"),
    longitude: float = Query(..., description="User's longitude"),
    radius: int = Query(10000, description="Search radius in meters (default 10km)"),
    limit: int = Query(10, description="Maximum number of results")
):
    """Find nearby Chartered Accountants using Google Places API"""
    try:
        if not GOOGLE_PLACES_API_KEY:
            print("Warning: GOOGLE_PLACES_API_KEY not configured")
            return {
                "success": False,
                "results": [],
                "count": 0,
                "error": "Google Places API key not configured",
                "user_location": {"latitude": latitude, "longitude": longitude}
            }
        
        # Use nearbysearch API
        url = f"{PLACES_API_BASE_URL}/nearbysearch/json"
        params = {
            "location": f"{latitude},{longitude}",
            "radius": radius,
            "type": "accounting",
            "keyword": "chartered accountant",
            "key": GOOGLE_PLACES_API_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        # Handle different API response statuses
        status = data.get("status")
        if status == "ZERO_RESULTS":
            return {
                "success": True,
                "results": [],
                "count": 0,
                "user_location": {"latitude": latitude, "longitude": longitude}
            }
        elif status not in ["OK", "ZERO_RESULTS"]:
            error_msg = f"Places API error: {status}"
            if status == "OVER_QUERY_LIMIT":
                error_msg += " - API quota exceeded"
            elif status == "REQUEST_DENIED":
                error_msg += " - Request denied (check API key permissions)"
            elif status == "INVALID_REQUEST":
                error_msg += " - Invalid request parameters"
            print(f"Places API error: {error_msg}")
            return {
                "success": False,
                "results": [],
                "count": 0,
                "error": error_msg,
                "user_location": {"latitude": latitude, "longitude": longitude}
            }
        
        places = data.get("results", [])
        
        # Process and enrich results
        ca_results = []
        for place in places[:limit]:
            try:
                # Validate required fields
                if "geometry" not in place or "location" not in place["geometry"]:
                    continue
                    
                place_lat = place["geometry"]["location"]["lat"]
                place_lng = place["geometry"]["location"]["lng"]
                distance = calculate_distance(latitude, longitude, place_lat, place_lng)
                
                # Get place details for phone number and website
                place_id = place.get("place_id")
                phone_number = None
                website = None
                opening_hours = None
                
                if place_id:
                    try:
                        details_url = f"{PLACES_API_BASE_URL}/details/json"
                        details_params = {
                            "place_id": place_id,
                            "fields": "formatted_phone_number,website,opening_hours",
                            "key": GOOGLE_PLACES_API_KEY
                        }
                        details_response = requests.get(details_url, params=details_params, timeout=5)
                        if details_response.status_code == 200:
                            details_data = details_response.json()
                            if details_data.get("status") == "OK":
                                result = details_data.get("result", {})
                                phone_number = result.get("formatted_phone_number")
                                website = result.get("website")
                                opening_hours = result.get("opening_hours")
                    except Exception as e:
                        print(f"Warning: Could not fetch place details for {place_id}: {e}")
                        pass  # Continue without details if fetch fails
                
                ca_result = {
                    "place_id": place_id,
                    "name": place.get("name", "Unknown"),
                    "address": place.get("vicinity") or place.get("formatted_address", ""),
                    "rating": place.get("rating", 0),
                    "user_ratings_total": place.get("user_ratings_total", 0),
                    "location": {
                        "latitude": place_lat,
                        "longitude": place_lng
                    },
                    "distance_km": round(distance, 2),
                    "phone_number": phone_number,
                    "website": website,
                    "is_open": place.get("opening_hours", {}).get("open_now") if place.get("opening_hours") else None,
                    "types": place.get("types", [])
                }
                ca_results.append(ca_result)
            except Exception as e:
                print(f"Warning: Error processing place: {e}")
                continue  # Skip this place and continue with others
        
        # Sort by distance
        ca_results.sort(key=lambda x: x["distance_km"])
        
        return {
            "success": True,
            "results": ca_results,
            "count": len(ca_results),
            "user_location": {"latitude": latitude, "longitude": longitude}
        }
        
    except requests.RequestException as e:
        print(f"Error calling Places API: {e}")
        return {
            "success": False,
            "results": [],
            "count": 0,
            "error": f"Error calling Places API: {str(e)}",
            "user_location": {"latitude": latitude, "longitude": longitude}
        }
    except Exception as e:
        print(f"Error finding nearby CAs: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "results": [],
            "count": 0,
            "error": f"Error finding nearby CAs: {str(e)}",
            "user_location": {"latitude": latitude, "longitude": longitude}
        }

async def _get_tax_deadlines_internal(financial_year: Optional[str] = None):
    """Internal function to get tax deadlines - can be called from endpoints or other functions"""
    current_year = datetime.now().year
    current_month = datetime.now().month
    
    # Determine financial year if not provided
    if not financial_year:
        if current_month >= 4:  # April onwards
            financial_year = f"{current_year}-{str(current_year + 1)[2:]}"
        else:
            financial_year = f"{current_year - 1}-{str(current_year)[2:]}"
    
    # Tax deadlines for India
    deadlines = []
    
    # Calculate dates based on current financial year
    fy_start_year = int(financial_year.split("-")[0])
    fy_end_year = fy_start_year + 1
    
    # ITR Filing Deadlines
    deadlines.append({
        "title": "ITR Filing Deadline (Individual)",
        "date": f"{fy_end_year}-07-31",
        "type": "deadline",
        "priority": "high",
        "description": "Last date to file Income Tax Return for individuals",
        "category": "filing"
    })
    
    deadlines.append({
        "title": "ITR Filing Deadline (Business)",
        "date": f"{fy_end_year}-10-31",
        "type": "deadline",
        "priority": "high",
        "description": "Last date to file Income Tax Return for businesses",
        "category": "filing"
    })
    
    # Advance Tax Deadlines
    deadlines.append({
        "title": "Advance Tax - Q1",
        "date": f"{fy_start_year}-06-15",
        "type": "deadline",
        "priority": "medium",
        "description": "First installment of advance tax (15% of estimated tax)",
        "category": "advance_tax"
    })
    
    deadlines.append({
        "title": "Advance Tax - Q2",
        "date": f"{fy_start_year}-09-15",
        "type": "deadline",
        "priority": "medium",
        "description": "Second installment of advance tax (45% of estimated tax)",
        "category": "advance_tax"
    })
    
    deadlines.append({
        "title": "Advance Tax - Q3",
        "date": f"{fy_start_year}-12-15",
        "type": "deadline",
        "priority": "medium",
        "description": "Third installment of advance tax (75% of estimated tax)",
        "category": "advance_tax"
    })
    
    deadlines.append({
        "title": "Advance Tax - Q4",
        "date": f"{fy_end_year}-03-15",
        "type": "deadline",
        "priority": "medium",
        "description": "Final installment of advance tax (100% of estimated tax)",
        "category": "advance_tax"
    })
    
    # TDS Certificate Deadline
    deadlines.append({
        "title": "TDS Certificate (Form 16) Due Date",
        "date": f"{fy_end_year}-06-15",
        "type": "deadline",
        "priority": "medium",
        "description": "Employers must issue Form 16 to employees",
        "category": "tds"
    })
        
    # Calculate days until each deadline
    today = datetime.now().date()
    for deadline in deadlines:
        deadline_date = datetime.strptime(deadline["date"], "%Y-%m-%d").date()
        days_until = (deadline_date - today).days
        deadline["days_until"] = days_until
        deadline["is_overdue"] = days_until < 0
        deadline["is_upcoming"] = 0 <= days_until <= 30
    
    # Sort by date
    deadlines.sort(key=lambda x: x["date"])
    
    return {
        "success": True,
        "financial_year": financial_year,
        "deadlines": deadlines,
        "count": len(deadlines)
    }

@app.get("/calendar/deadlines")
async def get_tax_deadlines(
    financial_year: Optional[str] = Query(None, description="Financial year (e.g., 2024-25)")
):
    """Get tax deadlines and important dates"""
    try:
        return await _get_tax_deadlines_internal(financial_year)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching tax deadlines: {str(e)}")

@app.post("/calendar/add-deadline")
async def add_user_deadline(
    user_id: str = Body(...),
    title: str = Body(...),
    date: str = Body(...),
    description: Optional[str] = Body(None),
    category: Optional[str] = Body("custom")
):
    """Add a custom deadline for the user"""
    try:
        deadline_data = {
            "user_id": user_id,
            "title": title,
            "date": date,
            "description": description,
            "category": category,
            "type": "custom",
            "created_at": datetime.utcnow(),
            "is_completed": False
        }
        
        doc_ref = db.collection('users').document(user_id).collection('deadlines').add(deadline_data)
        
        return {
            "success": True,
            "deadline_id": doc_ref[1].id,
            "deadline": deadline_data
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding deadline: {str(e)}")

@app.get("/calendar/user-deadlines/{user_id}")
async def get_user_deadlines(user_id: str):
    """Get all deadlines (system + custom) for a user"""
    try:
        # Get system deadlines
        system_deadlines = []
        try:
            deadlines_response = await _get_tax_deadlines_internal()
            system_deadlines = deadlines_response.get("deadlines", [])
        except Exception as e:
            print(f"Warning: Could not fetch system deadlines: {e}")
            import traceback
            traceback.print_exc()
        
        # Get custom deadlines
        custom_deadlines = []
        try:
            custom_docs = db.collection('users').document(user_id).collection('deadlines').stream()
            for doc in custom_docs:
                try:
                    deadline = doc.to_dict()
                    if not deadline:
                        continue
                    
                    deadline["deadline_id"] = doc.id
                    
                    # Validate and parse date
                    if "date" not in deadline:
                        print(f"Warning: Deadline {doc.id} missing date field")
                        continue
                    
                    try:
                        # Handle both string and date objects from Firestore
                        if isinstance(deadline["date"], str):
                            deadline_date = datetime.strptime(deadline["date"], "%Y-%m-%d").date()
                        elif hasattr(deadline["date"], "date"):
                            deadline_date = deadline["date"].date()
                        else:
                            print(f"Warning: Invalid date format for deadline {doc.id}")
                            continue
                    except (ValueError, AttributeError) as e:
                        print(f"Warning: Could not parse date for deadline {doc.id}: {e}")
                        continue
                    
                    today = datetime.now().date()
                    deadline["days_until"] = (deadline_date - today).days
                    deadline["is_overdue"] = deadline["days_until"] < 0
                    deadline["is_upcoming"] = 0 <= deadline["days_until"] <= 30
                    custom_deadlines.append(deadline)
                except Exception as e:
                    print(f"Warning: Error processing custom deadline {doc.id}: {e}")
                    continue
        except Exception as e:
            print(f"Warning: Could not fetch custom deadlines: {e}")
            import traceback
            traceback.print_exc()
        
        # Combine and sort
        all_deadlines = system_deadlines + custom_deadlines
        
        # Sort by date, handling missing dates gracefully
        try:
            all_deadlines.sort(key=lambda x: x.get("date", ""))
        except Exception as e:
            print(f"Warning: Error sorting deadlines: {e}")
        
        return {
            "success": True,
            "deadlines": all_deadlines,
            "count": len(all_deadlines),
            "upcoming_count": sum(1 for d in all_deadlines if d.get("is_upcoming", False)),
            "overdue_count": sum(1 for d in all_deadlines if d.get("is_overdue", False))
        }
        
    except Exception as e:
        print(f"Error fetching user deadlines: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error fetching user deadlines: {str(e)}")

def calculate_tax_summary(documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Calculate tax summary from user documents"""
    
    # Initialize summary structure
    summary = {
        "income": {
            "total_salary": 0,
            "employer_name": "",
            "pan": "",
            "other_income": 0,
            "bank_interest": 0,
            "capital_gains": 0
        },
        "tds": {
            "tds_deducted": 0,
            "advance_tax": 0,
            "self_assessment_tax": 0
        },
        "deductions": {
            "section_80c": {
                "total": 0,
                "details": []
            },
            "section_80d": {
                "total": 0,
                "details": []
            },
            "hra": {
                "total": 0,
                "details": []
            },
            "nps": {
                "total": 0,
                "details": []
            },
            "home_loan_interest": 0,
            "education_loan_interest": 0,
            "donations": 0
        },
        "tax_estimate": {
            "taxable_income": 0,
            "total_tax": 0,
            "net_payable": 0,
            "net_refundable": 0
        }
    }
    
    # Process documents
    for doc in documents:
        doc_type = doc.get('document_type', '')
        metadata = doc.get('metadata', {})
        
        if doc_type == 'salary_slip':
            # Extract salary information
            gross_salary = float(metadata.get('gross_salary', 0) or 0)
            net_salary = float(metadata.get('net_salary', 0) or 0)
            tds = float(metadata.get('tds', 0) or 0)
            
            summary['income']['total_salary'] += gross_salary
            summary['tds']['tds_deducted'] += tds
            
            if not summary['income']['employer_name']:
                summary['income']['employer_name'] = metadata.get('employer', '')
            if not summary['income']['pan']:
                summary['income']['pan'] = metadata.get('pan', '')
        
        elif doc_type == 'form_16':
            total_income = float(metadata.get('total_income', 0) or 0)
            tds = float(metadata.get('tds', 0) or 0)
            
            summary['income']['total_salary'] = max(summary['income']['total_salary'], total_income)
            summary['tds']['tds_deducted'] += tds
            
            if not summary['income']['employer_name']:
                summary['income']['employer_name'] = metadata.get('employer_name', '')
        
        elif doc_type == 'bank_interest_certificate':
            interest = float(metadata.get('interest_amount', 0) or 0)
            summary['income']['bank_interest'] += interest
        
        elif doc_type == 'investment_proof':
            section = metadata.get('section', '').upper()
            amount = float(metadata.get('amount', 0) or 0)
            investment_type = metadata.get('investment_type', '')
            
            if '80C' in section or section == '80C':
                summary['deductions']['section_80c']['total'] += amount
                summary['deductions']['section_80c']['details'].append({
                    "type": investment_type,
                    "amount": amount
                })
            elif '80D' in section or section == '80D':
                summary['deductions']['section_80d']['total'] += amount
                summary['deductions']['section_80d']['details'].append({
                    "type": investment_type,
                    "amount": amount
                })
        
        elif doc_type == 'home_loan_statement':
            if metadata.get('component', '').lower() == 'interest':
                interest = float(metadata.get('amount', 0) or 0)
                summary['deductions']['home_loan_interest'] += interest
        
        elif doc_type == 'rent_receipt':
            rent = float(metadata.get('monthly_rent', 0) or 0)
            # HRA calculation (simplified - typically 50% of basic for metro cities)
            hra_amount = rent * 12  # Annual rent
            summary['deductions']['hra']['total'] += hra_amount
            summary['deductions']['hra']['details'].append({
                "monthly_rent": rent,
                "annual_rent": hra_amount
            })
        
        elif doc_type == 'education_loan':
            interest = float(metadata.get('interest_amount', 0) or 0)
            summary['deductions']['education_loan_interest'] += interest
        
        elif doc_type == 'donation_receipt':
            amount = float(metadata.get('amount', 0) or 0)
            summary['deductions']['donations'] += amount
        
        elif doc_type == 'capital_gains':
            gains = float(metadata.get('gains_amount', 0) or 0)
            summary['income']['capital_gains'] += gains
    
    # Calculate other income
    summary['income']['other_income'] = (
        summary['income']['bank_interest'] + 
        summary['income']['capital_gains']
    )
    
    # Calculate total income
    total_income = (
        summary['income']['total_salary'] + 
        summary['income']['other_income']
    )
    
    # Calculate total deductions
    total_deductions = (
        min(summary['deductions']['section_80c']['total'], 150000) +  # 80C limit
        min(summary['deductions']['section_80d']['total'], 25000) +  # 80D limit (basic)
        min(summary['deductions']['hra']['total'], summary['income']['total_salary'] * 0.5) +  # HRA limit
        min(summary['deductions']['nps']['total'], 50000) +  # NPS limit
        min(summary['deductions']['home_loan_interest'], 200000) +  # Home loan interest limit
        min(summary['deductions']['education_loan_interest'], 40000) +  # Education loan limit
        summary['deductions']['donations']
    )
    
    # Calculate taxable income
    summary['tax_estimate']['taxable_income'] = max(0, total_income - total_deductions - 50000)  # Standard deduction
    
    # Calculate tax (simplified tax slabs for FY 2023-24)
    taxable = summary['tax_estimate']['taxable_income']
    tax = 0
    
    if taxable > 1500000:
        tax = 187500 + (taxable - 1500000) * 0.30
    elif taxable > 1200000:
        tax = 112500 + (taxable - 1200000) * 0.20
    elif taxable > 900000:
        tax = 67500 + (taxable - 900000) * 0.15
    elif taxable > 700000:
        tax = 37500 + (taxable - 700000) * 0.10
    elif taxable > 500000:
        tax = 12500 + (taxable - 500000) * 0.05
    elif taxable > 250000:
        tax = (taxable - 250000) * 0.05
    
    summary['tax_estimate']['total_tax'] = tax
    summary['tax_estimate']['net_payable'] = max(0, tax - summary['tds']['tds_deducted'])
    summary['tax_estimate']['net_refundable'] = max(0, summary['tds']['tds_deducted'] - tax)
    
    return summary

async def calculate_tax_regime_comparison(tax_summary: Dict[str, Any], user_documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Use Gemini to compare old vs new tax regime and provide recommendations"""
    
    # Prepare context
    context = {
        "income": tax_summary['income'],
        "deductions": tax_summary['deductions'],
        "tax_estimate": tax_summary['tax_estimate']
    }
    
    prompt = f"""
    You are a tax advisor for Indian income tax. Analyze the following tax summary and provide a comparison between Old Tax Regime and New Tax Regime (Section 115BAC).
    
    Tax Summary:
    {json.dumps(context, indent=2)}
    
    Please provide:
    1. Tax calculation for Old Regime (with all deductions)
    2. Tax calculation for New Regime (with reduced tax rates, no deductions except standard deduction)
    3. Which regime is better for this taxpayer and why
    4. Specific recommendations
    
    Return a JSON object with this structure:
    {{
        "old_regime": {{
            "taxable_income": <number>,
            "total_tax": <number>,
            "effective_rate": <percentage>
        }},
        "new_regime": {{
            "taxable_income": <number>,
            "total_tax": <number>,
            "effective_rate": <percentage>
        }},
        "recommended_regime": "old" or "new",
        "savings": <amount saved by choosing recommended regime>,
        "explanation": "<detailed explanation of why this regime is better>",
        "recommendations": ["<recommendation 1>", "<recommendation 2>", ...]
    }}
    
    Important: Use Indian tax slabs for FY 2023-24.
    Old Regime: Standard deduction of ₹50,000, then apply old tax slabs
    New Regime: Standard deduction of ₹50,000, then apply new tax slabs (0-3L: 0%, 3-7L: 5%, 7-10L: 10%, 10-12L: 15%, 12-15L: 20%, 15L+: 30%)
    """
    
    try:
        model = genai.GenerativeModel('gemini-2.0-flash')
        response = model.generate_content(prompt)
        
        # Parse JSON from response
        response_text = response.text
        json_start = response_text.find('{')
        json_end = response_text.rfind('}') + 1
        
        if json_start != -1 and json_end != 0:
            json_str = response_text[json_start:json_end]
            result = json.loads(json_str)
            return result
        else:
            # Fallback calculation
            return {
                "old_regime": {
                    "taxable_income": context['tax_estimate']['taxable_income'],
                    "total_tax": context['tax_estimate']['total_tax'],
                    "effective_rate": (context['tax_estimate']['total_tax'] / max(context['tax_estimate']['taxable_income'], 1)) * 100
                },
                "new_regime": {
                    "taxable_income": context['income']['total_salary'] + context['income']['other_income'] - 50000,
                    "total_tax": 0,
                    "effective_rate": 0
                },
                "recommended_regime": "old",
                "savings": 0,
                "explanation": "Please consult with a tax advisor for detailed regime comparison.",
                "recommendations": []
            }
    except Exception as e:
        print(f"Error in regime comparison: {e}")
        # Return fallback
        taxable_old = context['tax_estimate']['taxable_income']
        taxable_new = max(0, context['income']['total_salary'] + context['income']['other_income'] - 50000)
        
        # Calculate new regime tax
        tax_new = 0
        if taxable_new > 1500000:
            tax_new = 187500 + (taxable_new - 1500000) * 0.30
        elif taxable_new > 1200000:
            tax_new = 112500 + (taxable_new - 1200000) * 0.20
        elif taxable_new > 900000:
            tax_new = 67500 + (taxable_new - 900000) * 0.15
        elif taxable_new > 700000:
            tax_new = 37500 + (taxable_new - 700000) * 0.10
        elif taxable_new > 500000:
            tax_new = 12500 + (taxable_new - 500000) * 0.05
        elif taxable_new > 250000:
            tax_new = (taxable_new - 250000) * 0.05
        
        return {
            "old_regime": {
                "taxable_income": taxable_old,
                "total_tax": context['tax_estimate']['total_tax'],
                "effective_rate": (context['tax_estimate']['total_tax'] / max(taxable_old, 1)) * 100
            },
            "new_regime": {
                "taxable_income": taxable_new,
                "total_tax": tax_new,
                "effective_rate": (tax_new / max(taxable_new, 1)) * 100
            },
            "recommended_regime": "old" if context['tax_estimate']['total_tax'] < tax_new else "new",
            "savings": abs(context['tax_estimate']['total_tax'] - tax_new),
            "explanation": "Based on your deductions, the old regime appears more beneficial.",
            "recommendations": ["Consider maximizing Section 80C investments", "Review HRA claims if applicable"]
        }

@app.get("/tax-summary/{user_id}")
async def get_tax_summary(user_id: str):
    """Get comprehensive tax summary and insights for a user"""
    try:
        # Get all user documents
        docs_query = db.collection('users').document(user_id).collection('documents')
        docs = docs_query.stream()
        
        documents = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            documents.append(doc_data)
        
        if not documents:
            return {
                "success": True,
                "message": "No documents found. Please upload documents to generate tax summary.",
                "summary": None,
                "regime_comparison": None
            }
        
        # Calculate tax summary
        tax_summary = calculate_tax_summary(documents)
        
        # Get regime comparison from Gemini
        regime_comparison = await calculate_tax_regime_comparison(tax_summary, documents)
        
        return {
            "success": True,
            "summary": tax_summary,
            "regime_comparison": regime_comparison,
            "financial_year": "2023-24"  # You can make this dynamic
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calculating tax summary: {str(e)}")

@app.get("/tax-summary/{user_id}/pdf")
async def get_tax_summary_pdf(user_id: str):
    """Generate and return PDF of tax summary"""
    try:
        # Get tax summary
        summary_response = await get_tax_summary(user_id)
        
        if not summary_response['success'] or not summary_response.get('summary'):
            raise HTTPException(status_code=404, detail="Tax summary not available")
        
        tax_summary = summary_response['summary']
        regime_comparison = summary_response.get('regime_comparison', {})
        
        # Create PDF in memory
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        styles = getSampleStyleSheet()
        
        # Custom styles
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#FF6D4D'),
            spaceAfter=30,
        )
        
        heading_style = ParagraphStyle(
            'CustomHeading',
            parent=styles['Heading2'],
            fontSize=16,
            textColor=colors.HexColor('#D5451B'),
            spaceAfter=12,
        )
        
        # Build PDF content
        story = []
        
        # Title
        story.append(Paragraph("Tax Summary & Insights", title_style))
        story.append(Spacer(1, 0.2*inch))
        
        # Income Summary
        story.append(Paragraph("Income Summary", heading_style))
        income_data = [
            ['Total Salary', f"₹{tax_summary['income']['total_salary']:,.2f}"],
            ['Employer', tax_summary['income']['employer_name'] or 'N/A'],
            ['PAN', tax_summary['income']['pan'] or 'N/A'],
            ['Other Income', f"₹{tax_summary['income']['other_income']:,.2f}"],
        ]
        income_table = Table(income_data, colWidths=[3*inch, 3*inch])
        income_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(income_table)
        story.append(Spacer(1, 0.3*inch))
        
        # TDS & Tax Paid
        story.append(Paragraph("TDS & Tax Paid", heading_style))
        tds_data = [
            ['TDS Deducted', f"₹{tax_summary['tds']['tds_deducted']:,.2f}"],
            ['Advance Tax', f"₹{tax_summary['tds']['advance_tax']:,.2f}"],
        ]
        tds_table = Table(tds_data, colWidths=[3*inch, 3*inch])
        tds_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(tds_table)
        story.append(Spacer(1, 0.3*inch))
        
        # Deductions
        story.append(Paragraph("Deductions Detected", heading_style))
        deductions_data = [
            ['Section 80C', f"₹{tax_summary['deductions']['section_80c']['total']:,.2f}"],
            ['Section 80D', f"₹{tax_summary['deductions']['section_80d']['total']:,.2f}"],
            ['HRA', f"₹{tax_summary['deductions']['hra']['total']:,.2f}"],
            ['NPS', f"₹{tax_summary['deductions']['nps']['total']:,.2f}"],
            ['Home Loan Interest', f"₹{tax_summary['deductions']['home_loan_interest']:,.2f}"],
        ]
        deductions_table = Table(deductions_data, colWidths=[3*inch, 3*inch])
        deductions_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(deductions_table)
        story.append(Spacer(1, 0.3*inch))
        
        # Tax Estimate
        story.append(Paragraph("Tax Estimate", heading_style))
        tax_data = [
            ['Taxable Income', f"₹{tax_summary['tax_estimate']['taxable_income']:,.2f}"],
            ['Total Tax', f"₹{tax_summary['tax_estimate']['total_tax']:,.2f}"],
            ['Net Payable', f"₹{tax_summary['tax_estimate']['net_payable']:,.2f}"],
            ['Net Refundable', f"₹{tax_summary['tax_estimate']['net_refundable']:,.2f}"],
        ]
        tax_table = Table(tax_data, colWidths=[3*inch, 3*inch])
        tax_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(tax_table)
        
        # Regime Comparison
        if regime_comparison:
            story.append(PageBreak())
            story.append(Paragraph("Old vs New Tax Regime Comparison", heading_style))
            
            regime_data = [
                ['', 'Old Regime', 'New Regime'],
                ['Taxable Income', 
                 f"₹{regime_comparison.get('old_regime', {}).get('taxable_income', 0):,.2f}",
                 f"₹{regime_comparison.get('new_regime', {}).get('taxable_income', 0):,.2f}"],
                ['Total Tax',
                 f"₹{regime_comparison.get('old_regime', {}).get('total_tax', 0):,.2f}",
                 f"₹{regime_comparison.get('new_regime', {}).get('total_tax', 0):,.2f}"],
                ['Effective Rate',
                 f"{regime_comparison.get('old_regime', {}).get('effective_rate', 0):.2f}%",
                 f"{regime_comparison.get('new_regime', {}).get('effective_rate', 0):.2f}%"],
            ]
            
            regime_table = Table(regime_data, colWidths=[2*inch, 2*inch, 2*inch])
            regime_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#FF6D4D')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 12),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#FDF6EB')),
                ('TEXTCOLOR', (0, 1), (-1, -1), colors.black),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -1), 10),
                ('GRID', (0, 0), (-1, -1), 1, colors.grey),
            ]))
            story.append(regime_table)
            story.append(Spacer(1, 0.2*inch))
            
            # Recommendations
            if regime_comparison.get('explanation'):
                story.append(Paragraph("Recommendation", heading_style))
                story.append(Paragraph(regime_comparison['explanation'], styles['Normal']))
        
        # Build PDF
        doc.build(story)
        buffer.seek(0)
        
        # Return PDF as response
        from fastapi.responses import Response
        return Response(
            content=buffer.getvalue(),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=tax_summary_{user_id}.pdf"}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating PDF: {str(e)}")

# ==================== AUTO-FILING FEATURE ====================

def analyze_document_gaps(documents: List[Dict[str, Any]], financial_year: str = "2023-24") -> Dict[str, Any]:
    """Analyze uploaded documents and detect missing items"""
    
    required_documents = {
        "form_16": {
            "required": True,
            "parts": ["part_a", "part_b"],
            "description": "Form 16 (Part A & B) - Salary certificate from employer"
        },
        "form_26as": {
            "required": True,
            "description": "Form 26AS/AIS - Tax credit statement"
        },
        "salary_slip": {
            "required": False,
            "description": "Salary slips for all months"
        },
        "investment_proof": {
            "required": False,
            "sections": ["80C", "80D", "80G"],
            "description": "Investment proofs for deductions"
        },
        "rent_receipt": {
            "required": False,
            "description": "Rent receipts for HRA claim"
        },
        "home_loan_statement": {
            "required": False,
            "description": "Home loan interest certificate"
        },
        "bank_interest_certificate": {
            "required": False,
            "description": "Bank interest certificates"
        }
    }
    
    uploaded_doc_types = {doc.get('document_type', '') for doc in documents}
    
    missing_documents = []
    incomplete_documents = []
    recommendations = []
    
    # Check for Form 16
    form_16_docs = [d for d in documents if d.get('document_type') == 'form_16']
    if not form_16_docs:
        missing_documents.append({
            "type": "form_16",
            "priority": "high",
            "description": required_documents["form_16"]["description"],
            "action": "Upload Form 16 Part A and Part B from your employer"
        })
    else:
        # Check if both parts are present
        for doc in form_16_docs:
            metadata = doc.get('metadata', {})
            if not metadata.get('part_a') and not metadata.get('part_b'):
                incomplete_documents.append({
                    "type": "form_16",
                    "issue": "Missing Part A or Part B",
                    "action": "Ensure both Part A and Part B are uploaded"
                })
    
    # Check for Form 26AS
    if 'form_26as' not in uploaded_doc_types:
        missing_documents.append({
            "type": "form_26as",
            "priority": "high",
            "description": required_documents["form_26as"]["description"],
            "action": "Download Form 26AS from income tax portal and upload"
        })
    
    # Check for investment proofs if deductions are claimed
    investment_docs = [d for d in documents if d.get('document_type') == 'investment_proof']
    if not investment_docs:
        recommendations.append({
            "type": "investment_proof",
            "priority": "medium",
            "description": "Upload investment proofs to maximize deductions",
            "action": "Upload LIC receipts, PPF statements, ELSS certificates, etc."
        })
    
    # Check for rent receipts if HRA is applicable
    rent_docs = [d for d in documents if d.get('document_type') == 'rent_receipt']
    salary_docs = [d for d in documents if d.get('document_type') == 'salary_slip']
    if salary_docs and not rent_docs:
        recommendations.append({
            "type": "rent_receipt",
            "priority": "low",
            "description": "Rent receipts can help claim HRA deduction",
            "action": "Upload rent receipts if you're paying rent"
        })
    
    # Check for bank interest certificates
    if 'bank_interest_certificate' not in uploaded_doc_types:
        recommendations.append({
            "type": "bank_interest_certificate",
            "priority": "medium",
            "description": "Bank interest income needs to be declared",
            "action": "Upload bank interest certificates if interest > ₹40,000"
        })
    
    return {
        "missing_documents": missing_documents,
        "incomplete_documents": incomplete_documents,
        "recommendations": recommendations,
        "completion_percentage": calculate_completion_percentage(documents, required_documents),
        "status": "ready" if len(missing_documents) == 0 else "incomplete"
    }

def calculate_completion_percentage(documents: List[Dict[str, Any]], required_docs: Dict[str, Any]) -> float:
    """Calculate how complete the document collection is"""
    uploaded_types = {doc.get('document_type', '') for doc in documents}
    required_count = sum(1 for doc_type, info in required_docs.items() if info.get('required', False))
    uploaded_required = sum(1 for doc_type, info in required_docs.items() 
                           if info.get('required', False) and doc_type in uploaded_types)
    
    if required_count == 0:
        return 100.0
    
    base_percentage = (uploaded_required / required_count) * 80  # 80% for required docs
    optional_count = len([d for d in documents if not required_docs.get(d.get('document_type', ''), {}).get('required', False)])
    optional_bonus = min(optional_count * 5, 20)  # Up to 20% for optional docs
    
    return min(100.0, base_percentage + optional_bonus)

def check_consistencies(documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Check for inconsistencies across documents"""
    
    inconsistencies = []
    warnings = []
    
    # Extract key data points
    form_16_docs = [d for d in documents if d.get('document_type') == 'form_16']
    salary_slips = [d for d in documents if d.get('document_type') == 'salary_slip']
    form_26as_docs = [d for d in documents if d.get('document_type') == 'form_26as']
    
    # TDS Consistency Check
    tds_from_form16 = sum(float(d.get('metadata', {}).get('tds', 0) or 0) for d in form_16_docs)
    tds_from_salary = sum(float(d.get('metadata', {}).get('tds', 0) or 0) for d in salary_slips)
    tds_from_26as = sum(float(d.get('metadata', {}).get('total_tds', 0) or 0) for d in form_26as_docs)
    
    if tds_from_form16 > 0 and tds_from_26as > 0:
        tds_diff = abs(tds_from_form16 - tds_from_26as)
        if tds_diff > 100:  # Allow small rounding differences
            inconsistencies.append({
                "type": "tds_mismatch",
                "severity": "high",
                "description": f"TDS mismatch detected: Form 16 shows ₹{tds_from_form16:,.2f} but Form 26AS shows ₹{tds_from_26as:,.2f}",
                "difference": tds_diff,
                "action": "Verify TDS amounts in Form 16 and Form 26AS. Contact employer if discrepancy exists."
            })
    
    # Income Consistency Check
    income_from_form16 = sum(float(d.get('metadata', {}).get('total_income', 0) or 0) for d in form_16_docs)
    income_from_salary = sum(float(d.get('metadata', {}).get('gross_salary', 0) or 0) for d in salary_slips)
    
    if income_from_form16 > 0 and income_from_salary > 0:
        income_diff = abs(income_from_form16 - income_from_salary)
        if income_diff > income_from_form16 * 0.05:  # More than 5% difference
            warnings.append({
                "type": "income_variance",
                "severity": "medium",
                "description": f"Income variance: Form 16 shows ₹{income_from_form16:,.2f} but salary slips total ₹{income_from_salary:,.2f}",
                "difference": income_diff,
                "action": "Review if all salary slips are included or if there are other income sources"
            })
    
    # PAN Consistency Check
    pans = set()
    for doc in documents:
        pan = doc.get('metadata', {}).get('pan')
        if pan:
            pans.add(pan.upper())
    
    if len(pans) > 1:
        warnings.append({
            "type": "pan_mismatch",
            "severity": "medium",
            "description": f"Multiple PAN numbers found: {', '.join(pans)}",
            "action": "Ensure all documents belong to the same PAN"
        })
    
    # Missing 26AS entries check
    if form_26as_docs:
        for doc in form_26as_docs:
            metadata = doc.get('metadata', {})
            if not metadata.get('total_tds') or metadata.get('total_tds', 0) == 0:
                warnings.append({
                    "type": "missing_26as_data",
                    "severity": "low",
                    "description": "Form 26AS appears incomplete or missing TDS entries",
                    "action": "Verify Form 26AS is complete and matches your income sources"
                })
    
    return {
        "inconsistencies": inconsistencies,
        "warnings": warnings,
        "status": "clean" if len(inconsistencies) == 0 else "issues_found",
        "total_issues": len(inconsistencies) + len(warnings)
    }

def generate_itr_draft(documents: List[Dict[str, Any]], user_profile: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Generate ITR draft with auto-filled fields"""
    
    # Calculate tax summary first
    tax_summary = calculate_tax_summary(documents)
    
    # Extract profile information
    profile_data = user_profile or {}
    
    # Build ITR structure (simplified ITR-1/ITR-2 structure)
    itr_draft = {
        "financial_year": "2023-24",
        "assessment_year": "2024-25",
        "itr_form": "ITR-1",  # Can be determined based on income sources
        "personal_info": {
            "name": profile_data.get('name', ''),
            "pan": tax_summary['income'].get('pan', ''),
            "aadhaar": profile_data.get('aadhaar', ''),
            "dob": profile_data.get('dob', ''),
            "email": profile_data.get('email', ''),
            "mobile": profile_data.get('mobile', ''),
            "address": profile_data.get('address', {}),
        },
        "income_details": {
            "salary_income": {
                "gross_salary": tax_summary['income']['total_salary'],
                "tds": tax_summary['tds']['tds_deducted'],
                "employer_name": tax_summary['income']['employer_name'],
                "employer_tan": "",  # Extract from Form 16 if available
            },
            "other_income": {
                "interest_income": tax_summary['income']['bank_interest'],
                "capital_gains": tax_summary['income']['capital_gains'],
                "other_sources": 0,
            }
        },
        "deductions": {
            "section_80c": min(tax_summary['deductions']['section_80c']['total'], 150000),
            "section_80d": min(tax_summary['deductions']['section_80d']['total'], 25000),
            "section_80g": tax_summary['deductions']['donations'],
            "section_24b": min(tax_summary['deductions']['home_loan_interest'], 200000),  # Home loan interest
            "section_80e": min(tax_summary['deductions']['education_loan_interest'], 40000),
            "hra": min(tax_summary['deductions']['hra']['total'], tax_summary['income']['total_salary'] * 0.5),
            "standard_deduction": 50000,
        },
        "tax_computation": {
            "gross_total_income": tax_summary['income']['total_salary'] + tax_summary['income']['other_income'],
            "total_deductions": sum([
                min(tax_summary['deductions']['section_80c']['total'], 150000),
                min(tax_summary['deductions']['section_80d']['total'], 25000),
                min(tax_summary['deductions']['hra']['total'], tax_summary['income']['total_salary'] * 0.5),
                50000,  # Standard deduction
            ]),
            "taxable_income": tax_summary['tax_estimate']['taxable_income'],
            "tax_on_total_income": tax_summary['tax_estimate']['total_tax'],
            "tds": tax_summary['tds']['tds_deducted'],
            "advance_tax": tax_summary['tds']['advance_tax'],
            "self_assessment_tax": tax_summary['tds']['self_assessment_tax'],
            "net_tax_payable": tax_summary['tax_estimate']['net_payable'],
            "refund": tax_summary['tax_estimate']['net_refundable'],
        },
        "verification": {
            "place": "",
            "date": datetime.utcnow().strftime("%Y-%m-%d"),
            "signature_required": True,
        },
        "status": "draft",
        "last_updated": datetime.utcnow().isoformat(),
        "completeness": {
            "personal_info": 0.8,  # Estimate based on available data
            "income_details": 0.9,
            "deductions": 0.85,
            "overall": 0.85
        }
    }
    
    return itr_draft

def generate_checklist(documents: List[Dict[str, Any]], gap_analysis: Dict[str, Any], 
                      consistencies: Dict[str, Any]) -> Dict[str, Any]:
    """Generate comprehensive checklist for filing"""
    
    checklist = {
        "document_collection": {
            "status": "complete" if gap_analysis['status'] == "ready" else "incomplete",
            "items": []
        },
        "data_verification": {
            "status": "clean" if consistencies['status'] == "clean" else "review_needed",
            "items": []
        },
        "itr_preparation": {
            "status": "ready" if gap_analysis['status'] == "ready" else "pending",
            "items": []
        },
        "filing": {
            "status": "not_started",
            "items": []
        }
    }
    
    # Document collection items
    for missing in gap_analysis['missing_documents']:
        checklist["document_collection"]["items"].append({
            "task": f"Upload {missing['type'].replace('_', ' ').title()}",
            "status": "pending",
            "priority": missing['priority'],
            "description": missing['description']
        })
    
    for doc in documents:
        checklist["document_collection"]["items"].append({
            "task": f"Verify {doc.get('document_type', '').replace('_', ' ').title()}",
            "status": "completed",
            "priority": "low",
            "description": f"Document uploaded on {doc.get('uploaded_at', 'N/A')}"
        })
    
    # Data verification items
    for inconsistency in consistencies['inconsistencies']:
        checklist["data_verification"]["items"].append({
            "task": f"Resolve: {inconsistency['type'].replace('_', ' ').title()}",
            "status": "pending",
            "priority": inconsistency['severity'],
            "description": inconsistency['description']
        })
    
    for warning in consistencies['warnings']:
        checklist["data_verification"]["items"].append({
            "task": f"Review: {warning['type'].replace('_', ' ').title()}",
            "status": "pending",
            "priority": warning['severity'],
            "description": warning['description']
        })
    
    # ITR preparation items
    checklist["itr_preparation"]["items"] = [
        {
            "task": "Auto-fill ITR form",
            "status": "completed" if gap_analysis['status'] == "ready" else "pending",
            "priority": "high",
            "description": "ITR form will be auto-filled from uploaded documents"
        },
        {
            "task": "Review tax computation",
            "status": "pending",
            "priority": "high",
            "description": "Verify all calculations are correct"
        },
        {
            "task": "Verify deductions",
            "status": "pending",
            "priority": "medium",
            "description": "Ensure all deduction claims are supported by documents"
        }
    ]
    
    # Filing items
    checklist["filing"]["items"] = [
        {
            "task": "Generate ITR JSON",
            "status": "pending",
            "priority": "high",
            "description": "Generate JSON file for e-filing"
        },
        {
            "task": "Download ITR PDF",
            "status": "pending",
            "priority": "high",
            "description": "Download ITR form PDF for review"
        },
        {
            "task": "E-verify ITR",
            "status": "pending",
            "priority": "high",
            "description": "E-verify using Aadhaar OTP or Net Banking"
        }
    ]
    
    return checklist

@app.get("/auto-file/{user_id}/analysis")
async def get_auto_file_analysis(user_id: str):
    """Get comprehensive auto-filing analysis"""
    try:
        # Get all user documents
        docs_query = db.collection('users').document(user_id).collection('documents')
        docs = docs_query.stream()
        
        documents = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            documents.append(doc_data)
        
        # Get user profile if available
        user_profile = None
        try:
            profile_doc = db.collection('users').document(user_id).get()
            if profile_doc.exists:
                user_profile = profile_doc.to_dict()
        except:
            pass
        
        # Perform analysis
        gap_analysis = analyze_document_gaps(documents)
        consistencies = check_consistencies(documents)
        itr_draft = generate_itr_draft(documents, user_profile)
        checklist = generate_checklist(documents, gap_analysis, consistencies)
        
        return {
            "success": True,
            "gap_analysis": gap_analysis,
            "consistencies": consistencies,
            "itr_draft": itr_draft,
            "checklist": checklist,
            "completion_status": {
                "documents": gap_analysis['completion_percentage'],
                "verification": 100.0 if consistencies['status'] == "clean" else 50.0,
                "overall": (gap_analysis['completion_percentage'] + (100.0 if consistencies['status'] == "clean" else 50.0)) / 2
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in auto-file analysis: {str(e)}")

@app.get("/auto-file/{user_id}/itr-draft")
async def get_itr_draft(user_id: str):
    """Get ITR draft JSON"""
    try:
        docs_query = db.collection('users').document(user_id).collection('documents')
        docs = docs_query.stream()
        
        documents = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            documents.append(doc_data)
        
        user_profile = None
        try:
            profile_doc = db.collection('users').document(user_id).get()
            if profile_doc.exists:
                user_profile = profile_doc.to_dict()
        except:
            pass
        
        itr_draft = generate_itr_draft(documents, user_profile)
        
        return {
            "success": True,
            "itr_draft": itr_draft
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating ITR draft: {str(e)}")

@app.get("/auto-file/{user_id}/itr-preview-pdf")
async def get_itr_preview_pdf(user_id: str):
    """Generate ITR preview PDF"""
    try:
        # Get ITR draft
        draft_response = await get_itr_draft(user_id)
        if not draft_response['success']:
            raise HTTPException(status_code=404, detail="ITR draft not available")
        
        itr_draft = draft_response['itr_draft']
        
        # Create PDF
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        styles = getSampleStyleSheet()
        
        title_style = ParagraphStyle(
            'ITRTitle',
            parent=styles['Heading1'],
            fontSize=20,
            textColor=colors.HexColor('#FF6D4D'),
            spaceAfter=20,
        )
        
        heading_style = ParagraphStyle(
            'ITRHeading',
            parent=styles['Heading2'],
            fontSize=14,
            textColor=colors.HexColor('#D5451B'),
            spaceAfter=10,
        )
        
        story = []
        
        # Title
        story.append(Paragraph("ITR Draft Preview", title_style))
        story.append(Paragraph(f"Financial Year: {itr_draft['financial_year']}", styles['Normal']))
        story.append(Spacer(1, 0.2*inch))
        
        # Personal Info
        story.append(Paragraph("Personal Information", heading_style))
        personal_data = [
            ['Name', itr_draft['personal_info']['name'] or 'N/A'],
            ['PAN', itr_draft['personal_info']['pan'] or 'N/A'],
            ['Email', itr_draft['personal_info']['email'] or 'N/A'],
        ]
        personal_table = Table(personal_data, colWidths=[3*inch, 3*inch])
        personal_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(personal_table)
        story.append(Spacer(1, 0.3*inch))
        
        # Income Details
        story.append(Paragraph("Income Details", heading_style))
        income_data = [
            ['Gross Salary', f"₹{itr_draft['income_details']['salary_income']['gross_salary']:,.2f}"],
            ['Other Income', f"₹{itr_draft['income_details']['other_income']['interest_income'] + itr_draft['income_details']['other_income']['capital_gains']:,.2f}"],
            ['Gross Total Income', f"₹{itr_draft['tax_computation']['gross_total_income']:,.2f}"],
        ]
        income_table = Table(income_data, colWidths=[3*inch, 3*inch])
        income_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(income_table)
        story.append(Spacer(1, 0.3*inch))
        
        # Tax Computation
        story.append(Paragraph("Tax Computation", heading_style))
        tax_data = [
            ['Taxable Income', f"₹{itr_draft['tax_computation']['taxable_income']:,.2f}"],
            ['Tax on Total Income', f"₹{itr_draft['tax_computation']['tax_on_total_income']:,.2f}"],
            ['TDS', f"₹{itr_draft['tax_computation']['tds']:,.2f}"],
            ['Net Tax Payable', f"₹{itr_draft['tax_computation']['net_tax_payable']:,.2f}"],
            ['Refund', f"₹{itr_draft['tax_computation']['refund']:,.2f}"],
        ]
        tax_table = Table(tax_data, colWidths=[3*inch, 3*inch])
        tax_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#FDF6EB')),
            ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ]))
        story.append(tax_table)
        
        story.append(Spacer(1, 0.3*inch))
        story.append(Paragraph("Note: This is a draft preview. Please verify all details before filing.", 
                              styles['Normal']))
        
        doc.build(story)
        buffer.seek(0)
        
        from fastapi.responses import Response
        return Response(
            content=buffer.getvalue(),
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename=itr_draft_{user_id}.pdf"}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating ITR preview PDF: {str(e)}")

# ==================== REAL-TIME TAX INSIGHTS FEED ====================

def generate_tax_insights(documents: List[Dict[str, Any]], tax_summary: Dict[str, Any], 
                          consistencies: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate real-time tax insights from documents and analysis"""
    
    insights = []
    
    # Opportunity Insights
    opportunities = detect_opportunities(documents, tax_summary)
    insights.extend(opportunities)
    
    # Risk Insights
    risks = detect_risks(documents, tax_summary, consistencies)
    insights.extend(risks)
    
    # Deadline Insights
    deadlines = get_upcoming_deadlines()
    insights.extend(deadlines)
    
    # Optimization Insights
    optimizations = suggest_optimizations(tax_summary)
    insights.extend(optimizations)
    
    # Sort by priority and timestamp
    insights.sort(key=lambda x: (
        {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}.get(x.get('priority', 'low'), 3),
        x.get('timestamp', '')
    ))
    
    return insights

def detect_opportunities(documents: List[Dict[str, Any]], tax_summary: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Detect tax-saving opportunities"""
    
    opportunities = []
    
    # HRA Opportunity
    rent_docs = [d for d in documents if d.get('document_type') == 'rent_receipt']
    salary_docs = [d for d in documents if d.get('document_type') == 'salary_slip']
    
    if salary_docs and not rent_docs:
        total_rent = sum(float(d.get('metadata', {}).get('monthly_rent', 0) or 0) * 12 for d in rent_docs)
        if total_rent > 0:
            hra_claimable = min(total_rent, tax_summary['income']['total_salary'] * 0.5)
            if hra_claimable > tax_summary['deductions']['hra']['total']:
                opportunities.append({
                    "type": "opportunity",
                    "category": "hra_claim",
                    "title": "HRA Claim Opportunity",
                    "message": f"Your rent receipts total ₹{total_rent:,.0f} → You can claim up to ₹{hra_claimable:,.0f} as HRA deduction.",
                    "priority": "high",
                    "action": "Upload rent receipts to maximize HRA deduction",
                    "potential_savings": calculate_tax_savings(hra_claimable - tax_summary['deductions']['hra']['total'], tax_summary),
                    "timestamp": datetime.utcnow().isoformat()
                })
    
    # Section 80C Opportunity
    current_80c = tax_summary['deductions']['section_80c']['total']
    max_80c = 150000
    if current_80c < max_80c:
        remaining = max_80c - current_80c
        if remaining > 10000:  # Only suggest if significant amount
            opportunities.append({
                "type": "opportunity",
                "category": "section_80c",
                "title": "Maximize Section 80C",
                "message": f"You've claimed ₹{current_80c:,.0f} under Section 80C. You can invest ₹{remaining:,.0f} more to maximize deduction.",
                "priority": "medium",
                "action": "Consider investing in ELSS, PPF, or LIC to maximize Section 80C",
                "potential_savings": calculate_tax_savings(remaining, tax_summary),
                "timestamp": datetime.utcnow().isoformat()
            })
    
    # Section 80D Opportunity
    current_80d = tax_summary['deductions']['section_80d']['total']
    max_80d = 25000  # Basic limit, can be 50000 for senior citizens
    if current_80d < max_80d:
        remaining = max_80d - current_80d
        if remaining > 5000:
            opportunities.append({
                "type": "opportunity",
                "category": "section_80d",
                "title": "Health Insurance Deduction",
                "message": f"You can claim ₹{remaining:,.0f} more under Section 80D for health insurance premiums.",
                "priority": "medium",
                "action": "Review your health insurance premiums to maximize Section 80D",
                "potential_savings": calculate_tax_savings(remaining, tax_summary),
                "timestamp": datetime.utcnow().isoformat()
            })
    
    # NPS Opportunity
    nps_total = tax_summary['deductions']['nps']['total']
    max_nps = 50000
    if nps_total < max_nps:
        remaining = max_nps - nps_total
        if remaining > 10000:
            opportunities.append({
                "type": "opportunity",
                "category": "nps",
                "title": "NPS Contribution Opportunity",
                "message": f"Consider contributing ₹{remaining:,.0f} more to NPS for additional tax benefit under Section 80CCD(1B).",
                "priority": "low",
                "action": "Increase NPS contribution to maximize tax savings",
                "potential_savings": calculate_tax_savings(remaining, tax_summary),
                "timestamp": datetime.utcnow().isoformat()
            })
    
    return opportunities

def detect_risks(documents: List[Dict[str, Any]], tax_summary: Dict[str, Any], 
                consistencies: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Detect tax risks and issues"""
    
    risks = []
    
    # TDS Mismatch Risk
    for inconsistency in consistencies.get('inconsistencies', []):
        if inconsistency.get('type') == 'tds_mismatch':
            risks.append({
                "type": "risk",
                "category": "tds_mismatch",
                "title": "TDS Mismatch Detected",
                "message": inconsistency.get('description', ''),
                "priority": "critical",
                "action": inconsistency.get('action', ''),
                "impact": "May result in tax notice or refund delay",
                "timestamp": datetime.utcnow().isoformat()
            })
    
    # Missing Form 26AS
    form_26as_docs = [d for d in documents if d.get('document_type') == 'form_26as']
    if not form_26as_docs:
        risks.append({
            "type": "risk",
            "category": "missing_26as",
            "title": "Form 26AS Not Uploaded",
            "message": "TDS credited in 26AS but not verified → You may get a mismatch during ITR processing.",
            "priority": "high",
            "action": "Download and upload Form 26AS from income tax portal",
            "impact": "ITR may be rejected or delayed",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    # Income Declaration Risk
    other_income = tax_summary['income']['other_income']
    if other_income > 0:
        bank_interest = tax_summary['income']['bank_interest']
        if bank_interest > 40000 and not any(d.get('document_type') == 'bank_interest_certificate' for d in documents):
            risks.append({
                "type": "risk",
                "category": "undeclared_income",
                "title": "Bank Interest Declaration",
                "message": f"Your bank interest (₹{bank_interest:,.0f}) exceeds ₹40,000 threshold. Ensure proper declaration.",
                "priority": "medium",
                "action": "Upload bank interest certificates and declare in ITR",
                "impact": "May attract penalty for non-declaration",
                "timestamp": datetime.utcnow().isoformat()
            })
    
    # High Tax Payable Risk
    net_payable = tax_summary['tax_estimate']['net_payable']
    if net_payable > 10000:
        risks.append({
            "type": "risk",
            "category": "high_tax_payable",
            "title": "High Tax Payable",
            "message": f"You have ₹{net_payable:,.0f} tax payable. Consider advance tax to avoid interest charges.",
            "priority": "high",
            "action": "Pay advance tax before March 15 to avoid interest under Section 234B/234C",
            "impact": "Interest charges if not paid on time",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    return risks

def get_upcoming_deadlines() -> List[Dict[str, Any]]:
    """Get upcoming tax deadlines and nudges"""
    
    deadlines = []
    today = datetime.utcnow()
    current_year = today.year
    
    # Advance Tax Deadlines (FY 2023-24)
    advance_tax_dates = [
        (datetime(current_year, 6, 15), "Q1 Advance Tax"),
        (datetime(current_year, 9, 15), "Q2 Advance Tax"),
        (datetime(current_year, 12, 15), "Q3 Advance Tax"),
        (datetime(current_year + 1, 3, 15), "Q4 Advance Tax"),
    ]
    
    for deadline_date, description in advance_tax_dates:
        days_until = (deadline_date - today).days
        if 0 <= days_until <= 7:  # Within 7 days
            priority = "critical" if days_until <= 3 else "high"
            deadlines.append({
                "type": "deadline",
                "category": "advance_tax",
                "title": f"{description} Due",
                "message": f"Quarterly Advance Tax due in {days_until} day{'s' if days_until != 1 else ''}.",
                "priority": priority,
                "action": f"Pay advance tax before {deadline_date.strftime('%B %d, %Y')}",
                "deadline_date": deadline_date.isoformat(),
                "days_remaining": days_until,
                "timestamp": datetime.utcnow().isoformat()
            })
    
    # ITR Filing Deadline (July 31)
    itr_deadline = datetime(current_year + 1, 7, 31)
    days_until_itr = (itr_deadline - today).days
    if 0 <= days_until_itr <= 30:
        priority = "critical" if days_until_itr <= 7 else "high"
        deadlines.append({
            "type": "deadline",
            "category": "itr_filing",
            "title": "ITR Filing Deadline",
            "message": f"ITR filing deadline in {days_until_itr} day{'s' if days_until_itr != 1 else ''}.",
            "priority": priority,
            "action": "File your ITR before July 31 to avoid penalty",
            "deadline_date": itr_deadline.isoformat(),
            "days_remaining": days_until_itr,
            "timestamp": datetime.utcnow().isoformat()
        })
    
    return deadlines

def suggest_optimizations(tax_summary: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Suggest tax optimization strategies"""
    
    optimizations = []
    
    # Regime Comparison Suggestion
    total_deductions = (
        min(tax_summary['deductions']['section_80c']['total'], 150000) +
        min(tax_summary['deductions']['section_80d']['total'], 25000) +
        tax_summary['deductions']['hra']['total']
    )
    
    if total_deductions > 200000:
        optimizations.append({
            "type": "optimization",
            "category": "regime_selection",
            "title": "Consider Old Tax Regime",
            "message": f"With deductions of ₹{total_deductions:,.0f}, the old regime may be more beneficial.",
            "priority": "medium",
            "action": "Compare old vs new regime in Tax Summary",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    # Standard Deduction Reminder
    if tax_summary['income']['total_salary'] > 0:
        optimizations.append({
            "type": "optimization",
            "category": "standard_deduction",
            "title": "Standard Deduction Applied",
            "message": "₹50,000 standard deduction has been automatically applied to your salary income.",
            "priority": "low",
            "action": "No action needed",
            "timestamp": datetime.utcnow().isoformat()
        })
    
    return optimizations

def calculate_tax_savings(additional_deduction: float, tax_summary: Dict[str, Any]) -> float:
    """Calculate potential tax savings from additional deduction"""
    taxable_income = tax_summary['tax_estimate']['taxable_income']
    new_taxable = max(0, taxable_income - additional_deduction)
    
    # Calculate tax on new taxable income
    new_tax = 0
    if new_taxable > 1500000:
        new_tax = 187500 + (new_taxable - 1500000) * 0.30
    elif new_taxable > 1200000:
        new_tax = 112500 + (new_taxable - 1200000) * 0.20
    elif new_taxable > 900000:
        new_tax = 67500 + (new_taxable - 900000) * 0.15
    elif new_taxable > 700000:
        new_tax = 37500 + (new_taxable - 700000) * 0.10
    elif new_taxable > 500000:
        new_tax = 12500 + (new_taxable - 500000) * 0.05
    elif new_taxable > 250000:
        new_tax = (new_taxable - 250000) * 0.05
    
    current_tax = tax_summary['tax_estimate']['total_tax']
    savings = current_tax - new_tax
    
    return max(0, savings)

def calculate_tax_health_score(documents: List[Dict[str, Any]], tax_summary: Dict[str, Any], 
                               consistencies: Dict[str, Any], gap_analysis: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate monthly Tax Health Score (0-100)"""
    
    score = 0
    max_score = 100
    factors = []
    
    # Document Completeness (30 points)
    doc_completeness = gap_analysis.get('completion_percentage', 0)
    doc_score = (doc_completeness / 100) * 30
    score += doc_score
    factors.append({
        "factor": "Document Completeness",
        "score": doc_score,
        "max_score": 30,
        "status": "excellent" if doc_completeness >= 90 else "good" if doc_completeness >= 70 else "needs_improvement"
    })
    
    # Data Consistency (25 points)
    consistency_status = consistencies.get('status', 'issues_found')
    if consistency_status == 'clean':
        consistency_score = 25
    else:
        total_issues = consistencies.get('total_issues', 0)
        consistency_score = max(0, 25 - (total_issues * 5))
    score += consistency_score
    factors.append({
        "factor": "Data Consistency",
        "score": consistency_score,
        "max_score": 25,
        "status": "excellent" if consistency_score >= 20 else "good" if consistency_score >= 15 else "needs_improvement"
    })
    
    # Deduction Optimization (20 points)
    total_deductions = (
        min(tax_summary['deductions']['section_80c']['total'], 150000) +
        min(tax_summary['deductions']['section_80d']['total'], 25000) +
        tax_summary['deductions']['hra']['total']
    )
    # Score based on deduction utilization (assuming optimal is 200k+)
    if total_deductions >= 200000:
        deduction_score = 20
    elif total_deductions >= 150000:
        deduction_score = 15
    elif total_deductions >= 100000:
        deduction_score = 10
    else:
        deduction_score = 5
    score += deduction_score
    factors.append({
        "factor": "Deduction Optimization",
        "score": deduction_score,
        "max_score": 20,
        "status": "excellent" if deduction_score >= 15 else "good" if deduction_score >= 10 else "needs_improvement"
    })
    
    # Tax Planning (15 points)
    # Check if user has advance tax paid, proper planning
    advance_tax = tax_summary['tds']['advance_tax']
    net_payable = tax_summary['tax_estimate']['net_payable']
    if net_payable <= 0:  # Refund or break-even
        planning_score = 15
    elif advance_tax > 0:
        planning_score = 12
    elif net_payable < 10000:
        planning_score = 10
    else:
        planning_score = 5
    score += planning_score
    factors.append({
        "factor": "Tax Planning",
        "score": planning_score,
        "max_score": 15,
        "status": "excellent" if planning_score >= 12 else "good" if planning_score >= 8 else "needs_improvement"
    })
    
    # Compliance (10 points)
    # Check if all required documents are present
    missing_docs = len(gap_analysis.get('missing_documents', []))
    if missing_docs == 0:
        compliance_score = 10
    elif missing_docs == 1:
        compliance_score = 7
    elif missing_docs == 2:
        compliance_score = 4
    else:
        compliance_score = 0
    score += compliance_score
    factors.append({
        "factor": "Compliance",
        "score": compliance_score,
        "max_score": 10,
        "status": "excellent" if compliance_score >= 8 else "good" if compliance_score >= 5 else "needs_improvement"
    })
    
    # Round to nearest integer
    score = round(score)
    
    # Determine health level
    if score >= 85:
        health_level = "excellent"
        health_message = "Your tax health is excellent! Keep up the good work."
    elif score >= 70:
        health_level = "good"
        health_message = "Your tax health is good. A few improvements can make it excellent."
    elif score >= 55:
        health_level = "fair"
        health_message = "Your tax health is fair. Focus on document completeness and deductions."
    else:
        health_level = "needs_improvement"
        health_message = "Your tax health needs improvement. Upload missing documents and optimize deductions."
    
    return {
        "score": score,
        "max_score": max_score,
        "health_level": health_level,
        "health_message": health_message,
        "factors": factors,
        "month": datetime.utcnow().strftime("%Y-%m"),
        "timestamp": datetime.utcnow().isoformat(),
        "previous_score": None  # Can be fetched from history
    }

@app.get("/insights/{user_id}")
async def get_tax_insights(user_id: str):
    """Get real-time tax insights feed"""
    try:
        # Get all user documents
        docs_query = db.collection('users').document(user_id).collection('documents')
        docs = docs_query.stream()
        
        documents = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            documents.append(doc_data)
        
        if not documents:
            return {
                "success": True,
                "insights": [],
                "message": "Upload documents to get personalized tax insights"
            }
        
        # Calculate tax summary
        tax_summary = calculate_tax_summary(documents)
        
        # Check consistencies
        consistencies = check_consistencies(documents)
        
        # Analyze gaps
        gap_analysis = analyze_document_gaps(documents)
        
        # Generate insights
        insights = generate_tax_insights(documents, tax_summary, consistencies)
        
        # Calculate tax health score
        health_score = calculate_tax_health_score(documents, tax_summary, consistencies, gap_analysis)
        
        return {
            "success": True,
            "insights": insights,
            "health_score": health_score,
            "total_insights": len(insights),
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating insights: {str(e)}")

@app.get("/insights/{user_id}/health-score")
async def get_health_score(user_id: str):
    """Get current tax health score"""
    try:
        docs_query = db.collection('users').document(user_id).collection('documents')
        docs = docs_query.stream()
        
        documents = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data['id'] = doc.id
            documents.append(doc_data)
        
        if not documents:
            return {
                "success": True,
                "health_score": {
                    "score": 0,
                    "max_score": 100,
                    "health_level": "needs_improvement",
                    "health_message": "Upload documents to calculate your tax health score",
                    "factors": []
                }
            }
        
        tax_summary = calculate_tax_summary(documents)
        consistencies = check_consistencies(documents)
        gap_analysis = analyze_document_gaps(documents)
        
        health_score = calculate_tax_health_score(documents, tax_summary, consistencies, gap_analysis)
        
        # Get previous month's score for comparison
        try:
            health_history = db.collection('users').document(user_id).collection('health_scores')
            prev_month = (datetime.utcnow() - timedelta(days=30)).strftime("%Y-%m")
            prev_docs = health_history.where('month', '==', prev_month).limit(1).stream()
            prev_score_data = None
            for doc in prev_docs:
                prev_score_data = doc.to_dict()
                break
            
            if prev_score_data:
                health_score['previous_score'] = prev_score_data.get('score')
                health_score['score_change'] = health_score['score'] - prev_score_data.get('score', 0)
        except:
            pass
        
        # Store current score
        try:
            health_history = db.collection('users').document(user_id).collection('health_scores')
            health_history.add(health_score)
        except:
            pass
        
        return {
            "success": True,
            "health_score": health_score
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calculating health score: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)