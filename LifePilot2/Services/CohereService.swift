import Foundation
import Combine

// MARK: - Cohere API Models
struct CohereGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let maxTokens: Int
    let temperature: Double
    let stopSequences: [String]?
    
    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case maxTokens = "max_tokens"
        case temperature
        case stopSequences = "stop_sequences"
    }
}

struct CohereGenerateResponse: Decodable {
    let id: String
    let generations: [Generation]
    
    struct Generation: Decodable {
        let text: String
    }
}

enum CohereServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case rateLimitExceeded
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Error decoding response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Cohere API Service
protocol CohereServiceProtocol {
    func generateAnalysis(for userProfile: UserProfile) -> AnyPublisher<String, CohereServiceError>
}

class CohereService: CohereServiceProtocol {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func generateAnalysis(for userProfile: UserProfile) -> AnyPublisher<String, CohereServiceError> {
        guard let url = URL(string: AppConfig.Cohere.baseURL) else {
            return Fail(error: CohereServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        AppConfig.Debug.log("Generating analysis for user: \(userProfile.id)")
        
        // Create the prompt based on user profile information
        let prompt = createPromptForUserAnalysis(userProfile: userProfile)
        
        // Create the request body
        let requestBody = CohereGenerateRequest(
            model: AppConfig.Cohere.model,
            prompt: prompt,
            maxTokens: AppConfig.Cohere.maxTokens,
            temperature: AppConfig.Cohere.temperature,
            stopSequences: AppConfig.Cohere.stopSequences
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(AppConfig.cohereAPIKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try encoder.encode(requestBody)
            AppConfig.Debug.log("Request URL: \(url)")
            AppConfig.Debug.log("API Key: \(AppConfig.cohereAPIKey.prefix(5))...")
            AppConfig.Debug.log("Model: \(AppConfig.Cohere.model)")
            AppConfig.Debug.log("Max Tokens: \(AppConfig.Cohere.maxTokens)")
        } catch {
            return Fail(error: .networkError(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                // Check for HTTP response status
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CohereServiceError.networkError(NSError(domain: "HTTPResponse", code: 0, userInfo: nil))
                }
                
                // Log response status
                AppConfig.Debug.log("Response status code: \(httpResponse.statusCode)")
                
                // Check for specific status codes
                switch httpResponse.statusCode {
                case 200, 201:
                    // Success, continue
                    return data
                case 429:
                    throw CohereServiceError.rateLimitExceeded
                case 400...499:
                    // Client error
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Client error"
                    throw CohereServiceError.apiError("Client error: \(errorMessage)")
                case 500...599:
                    // Server error
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
                    throw CohereServiceError.apiError("Server error: \(errorMessage)")
                default:
                    throw CohereServiceError.apiError("Unexpected status code: \(httpResponse.statusCode)")
                }
            }
            .mapError { error -> CohereServiceError in
                if let cohereError = error as? CohereServiceError {
                    return cohereError
                }
                return .networkError(error)
            }
            .flatMap { data -> AnyPublisher<String, CohereServiceError> in
                // Log the raw data response for debugging
                AppConfig.Debug.log("Raw response data length: \(data.count) bytes")
                if data.count < 1000 {
                    AppConfig.Debug.log("Raw response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                }
                
                return Just(data)
                    .decode(type: CohereGenerateResponse.self, decoder: self.decoder)
                    .mapError { error -> CohereServiceError in
                        AppConfig.Debug.error("Decoding error: \(error)")
                        if let decodingError = error as? DecodingError {
                            return .decodingError(decodingError)
                        } else {
                            return .apiError(error.localizedDescription)
                        }
                    }
                    .map { response in
                        guard let firstGeneration = response.generations.first else {
                            return ""
                        }
                        return firstGeneration.text
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func createPromptForUserAnalysis(userProfile: UserProfile) -> String {
        // Create a detailed prompt based on the user's profile information
        let sleepHabit = userProfile.sleepPreference.rawValue
        let activityLevel = userProfile.activityLevel.rawValue
        let personalityType = userProfile.personalityType ?? "Unknown"
        let focusAreas = userProfile.focusAreas.map { $0.rawValue }.joined(separator: ", ")
        let challenges = userProfile.currentChallenges.map { $0.rawValue }.joined(separator: ", ")
        
        return """
        You are LifePilot, an AI lifestyle coach. Analyze the following user profile and provide personalized insights and recommendations:
        
        User Profile:
        - Name: \(userProfile.name)
        - Personality Type: \(personalityType)
        - Sleep Preference: \(sleepHabit)
        - Activity Level: \(activityLevel)
        - Focus Areas: \(focusAreas.isEmpty ? "None specified" : focusAreas)
        - Current Challenges: \(challenges.isEmpty ? "None specified" : challenges)
        
        Based on this information, generate:
        1. Three to five key insights about the user's current habits and how they might impact their goals
        2. Four to six actionable recommendations that are personalized to their profile
        3. Evidence or scientific backing for why these recommendations would be effective
        
        IMPORTANT: Return ONLY a valid JSON object with NO additional text before or after. The response must be a properly formatted JSON object with the following structure:
        {
          "insights": [
            {"title": "Insight Title", "description": "Detailed explanation", "focusArea": "One of the user's focus areas", "severity": "Positive/Neutral/Needs Attention/Critical"}
          ],
          "recommendations": [
            {"title": "Recommendation Title", "description": "Detailed explanation", "focusArea": "Relevant focus area", "impact": "Low/Medium/High", "timeframe": "Immediate/Short Term/Medium Term/Long Term"}
          ],
          "evidenceLinks": [
            {"title": "Evidence Title", "url": "https://validurl.com", "type": "Article/Scientific Study/Book/Video/Podcast"}
          ]
        }
        
        Ensure the JSON is valid and complete. Do not include any text before or after the JSON object.
        """
    }
}

// MARK: - Analysis Parser
class AnalysisParser {
    static func parseAnalysisResponse(_ responseText: String) -> PersonalizedAnalysis? {
        AppConfig.Debug.log("Attempting to parse response text of length: \(responseText.count)")
        
        // Step 1: Clean the response
        var cleanedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the first '{' and last '}' to extract just the JSON part
        guard let startIndex = cleanedText.firstIndex(of: "{"),
              let endIndex = cleanedText.lastIndex(of: "}") else {
            AppConfig.Debug.error("No valid JSON found in response")
            return createFallbackAnalysis()
        }
        
        // Extract just the JSON part
        cleanedText = String(cleanedText[startIndex...endIndex])
        
        // Step 2: Fix common JSON issues
        cleanedText = cleanedText.replacingOccurrences(of: ",\\s*}", with: "}", options: .regularExpression)
        cleanedText = cleanedText.replacingOccurrences(of: ",\\s*]", with: "]", options: .regularExpression)
        
        // Step 3: Parse the JSON
        do {
            let data = cleanedText.data(using: .utf8)!
            let decoder = JSONDecoder()
            
            // Use custom types to handle flexible API response formats
            struct TempInsight: Decodable {
                let title: String
                let description: String
                let focusArea: String
                let severity: String
            }
            
            struct TempRecommendation: Decodable {
                let title: String
                let description: String
                let focusArea: String
                let impact: String
                let timeframe: String
            }
            
            struct TempEvidenceLink: Decodable {
                let title: String
                let url: String
                let type: String
            }
            
            struct TempAnalysis: Decodable {
                let insights: [TempInsight]
                let recommendations: [TempRecommendation]
                let evidenceLinks: [TempEvidenceLink]?
            }
            
            // Attempt to decode
            let tempAnalysis = try decoder.decode(TempAnalysis.self, from: data)
            
            // Map to our model types
            let insights = tempAnalysis.insights.map { tempInsight -> Insight in
                return Insight(
                    title: tempInsight.title,
                    description: tempInsight.description,
                    focusArea: FocusArea.fromString(tempInsight.focusArea),
                    severity: InsightSeverity.fromString(tempInsight.severity)
                )
            }
            
            let recommendations = tempAnalysis.recommendations.map { tempRec -> Recommendation in
                return Recommendation(
                    title: tempRec.title,
                    description: tempRec.description,
                    focusArea: FocusArea.fromString(tempRec.focusArea),
                    impact: RecommendationImpact.fromString(tempRec.impact),
                    timeframe: TimeFrame.fromString(tempRec.timeframe)
                )
            }
            
            var evidenceLinks: [EvidenceLink]? = nil
            if let tempLinks = tempAnalysis.evidenceLinks {
                evidenceLinks = tempLinks.compactMap { tempLink -> EvidenceLink? in
                    guard let url = URL(string: tempLink.url) else {
                        return nil
                    }
                    
                    return EvidenceLink(
                        title: tempLink.title,
                        url: url,
                        type: EvidenceType.fromString(tempLink.type)
                    )
                }
            }
            
            return PersonalizedAnalysis(
                id: UUID().uuidString,
                userId: UUID().uuidString, // Will be replaced by caller
                generatedAt: Date(),
                insights: insights,
                recommendations: recommendations,
                evidenceLinks: evidenceLinks
            )
        } catch {
            AppConfig.Debug.error("Error parsing analysis JSON: \(error)")
            return createFallbackAnalysis()
        }
    }
    
    // Create a fallback analysis for when parsing fails
    private static func createFallbackAnalysis() -> PersonalizedAnalysis {
        AppConfig.Debug.log("Creating fallback analysis")
        
        // Create some default insights
        let insights = [
            Insight(
                title: "System Generated Insight",
                description: "We couldn't process your personalized insights. This is a system-generated placeholder. Please try regenerating your analysis.",
                focusArea: .productivity,
                severity: .neutral
            ),
            Insight(
                title: "Default Health Recommendation",
                description: "Regular physical activity is important for overall well-being. Consider incorporating at least 30 minutes of moderate exercise into your daily routine.",
                focusArea: .health,
                severity: .neutral
            )
        ]
        
        // Create some default recommendations
        let recommendations = [
            Recommendation(
                title: "Try Again Later",
                description: "Our system encountered an issue generating your personalized recommendations. Please try again in a few minutes.",
                focusArea: .productivity,
                impact: .medium,
                timeframe: .immediate
            ),
            Recommendation(
                title: "Start a Daily Reflection Practice",
                description: "Spend 5 minutes each evening reflecting on your day and setting intentions for tomorrow.",
                focusArea: .mindfulness,
                impact: .medium,
                timeframe: .shortTerm
            )
        ]
        
        // Create a default evidence link
        let evidenceLinks = [
            EvidenceLink(
                title: "The Benefits of Mindfulness",
                url: URL(string: "https://www.health.harvard.edu/blog/mindfulness-meditation-may-ease-anxiety-mental-stress-201401086967")!,
                type: .article
            )
        ]
        
        return PersonalizedAnalysis(
            id: UUID().uuidString,
            userId: UUID().uuidString, // Will be replaced by caller
            generatedAt: Date(),
            insights: insights,
            recommendations: recommendations,
            evidenceLinks: evidenceLinks
        )
    }
}
