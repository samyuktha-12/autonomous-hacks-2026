class ApiConfig {
  // Development server URL (change this to your actual server URL)
  static const String devBaseUrl = 'http://10.0.2.2:8000';
  
  // Production server URL (update this when deploying)
  // Examples:
  // - Railway: 'https://your-app.railway.app'
  // - Render: 'https://taxmate-api.onrender.com'
  // - Heroku: 'https://taxmate-api.herokuapp.com'
  static const String prodBaseUrl = 'https://your-production-server.com';
  
  // Current environment - change this to 'prod' for production
  // Set to 'dev' for local development, 'prod' for deployed API
  static const String environment = 'dev';
  
  // Get the current base URL based on environment
  static String get baseUrl {
    return environment == 'prod' ? prodBaseUrl : devBaseUrl;
  }
  
  // API Endpoints
  static String get healthCheckEndpoint => '$baseUrl/health';
  static String get uploadDocumentEndpoint => '$baseUrl/upload-document';
  static String get documentsEndpoint => '$baseUrl/documents';
  static String get documentTypesEndpoint => '$baseUrl/document-types';
  
  // Helper method to get documents for a specific user
  static String getUserDocumentsEndpoint(String userId) => '$documentsEndpoint/$userId';
  
  // Helper method to delete a specific document
  static String getDeleteDocumentEndpoint(String userId, String documentId) => '$documentsEndpoint/$userId/$documentId';
  
  // Chat endpoints
  static String get chatEndpoint => '$baseUrl/chat';
  static String getChatHistoryEndpoint(String userId) => '$baseUrl/chat-history/$userId';
  
  // Tax Summary endpoints
  static String getTaxSummaryEndpoint(String userId) => '$baseUrl/tax-summary/$userId';
  static String getTaxSummaryPdfEndpoint(String userId) => '$baseUrl/tax-summary/$userId/pdf';
  
  // Auto-filing endpoints
  static String getAutoFileAnalysisEndpoint(String userId) => '$baseUrl/auto-file/$userId/analysis';
  static String getItrDraftEndpoint(String userId) => '$baseUrl/auto-file/$userId/itr-draft';
  static String getItrPreviewPdfEndpoint(String userId) => '$baseUrl/auto-file/$userId/itr-preview-pdf';
  
  // Tax Insights endpoints
  static String getTaxInsightsEndpoint(String userId) => '$baseUrl/insights/$userId';
  static String getHealthScoreEndpoint(String userId) => '$baseUrl/insights/$userId/health-score';
  
  // Places API endpoints
  static String getNearbyCaEndpoint(double latitude, double longitude, {int radius = 10000, int limit = 10}) => 
      '$baseUrl/places/nearby-ca?latitude=$latitude&longitude=$longitude&radius=$radius&limit=$limit';
  
  // Calendar endpoints
  static String getTaxDeadlinesEndpoint([String? financialYear]) => 
      financialYear != null ? '$baseUrl/calendar/deadlines?financial_year=$financialYear' : '$baseUrl/calendar/deadlines';
  static String getUserDeadlinesEndpoint(String userId) => '$baseUrl/calendar/user-deadlines/$userId';
  static String get getAddDeadlineEndpoint => '$baseUrl/calendar/add-deadline';
} 