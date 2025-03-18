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

enum CohereServiceError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case unknownError
}

// MARK: - Cohere API Service
protocol CohereServiceProtocol {
    func generateAnalysis(for userProfile: UserProfile) -> AnyPublisher<String, CohereServiceError>
}

class CohereService: CohereServiceProtocol {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func generateAnalysis(for userProfile: UserProfile) -> AnyPublisher<String, CohereServiceError> {
        guard let url = URL(string: AppConfig.Cohere.baseURL) else {
            return Fail(error: CohereServiceError.invalidURL).eraseToAnyPublisher()
        }
        
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
            request.httpBody = try JSONEncoder().encode(requestBody)
            print("Request URL: \(url)")
            print("API Key: \(AppConfig.cohereAPIKey.prefix(5))...")
            print("Model: \(AppConfig.Cohere.model)")
            print("Max Tokens: \(AppConfig.Cohere.maxTokens)")
        } catch {
            return Fail(error: .networkError(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .mapError { CohereServiceError.networkError($0) }
            .map { data, response -> Data in
                // Log the raw response to help with debugging
                print("Response status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                print("Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                return data
            }
            .decode(type: CohereGenerateResponse.self, decoder: JSONDecoder())
            .mapError { error -> CohereServiceError in
                print("Decoding error: \(error)")
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
    
    private func createPromptForUserAnalysis(userProfile: UserProfile) -> String {
        // Create a detailed prompt based on the user's profile information
        let sleepHabit = userProfile.sleepPreference.rawValue
        let activityLevel = userProfile.activityLevel.rawValue
        let focusAreas = userProfile.focusAreas.map { $0.rawValue }.joined(separator: ", ")
        let challenges = userProfile.currentChallenges.map { $0.rawValue }.joined(separator: ", ")
        
        return """
        You are LifePilot, an AI lifestyle coach. Analyze the following user profile and provide personalized insights and recommendations:
        
        User Profile:
        - Sleep Preference: \(sleepHabit)
        - Activity Level: \(activityLevel)
        - Focus Areas: \(focusAreas)
        - Current Challenges: \(challenges)
        
        Based on this information, generate:
        1. Three key insights about the user's current habits and how they might impact their goals
        2. Four actionable recommendations that are personalized to their profile
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
        
        Ensure the JSON is valid and complete. No text should appear before or after the JSON object.
        """
    }
}

// MARK: - Analysis Parser
class AnalysisParser {
    // Add the mapFocusArea function here
    private static func mapFocusArea(_ apiArea: String) -> FocusArea {
        let simplified = apiArea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if simplified.contains("sleep") {
            return .health
        } else if simplified.contains("activity") || simplified.contains("exercise") {
            return .health
        } else if simplified.contains("focus") || simplified.contains("productivity") {
            return .productivity
        } else if simplified.contains("work") || simplified.contains("career") {
            return .career
        } else if simplified.contains("relation") || simplified.contains("social") {
            return .relationships
        } else if simplified.contains("learn") || simplified.contains("skill") {
            return .learning
        } else if simplified.contains("mind") || simplified.contains("stress") {
            return .mindfulness
        } else if simplified.contains("financ") || simplified.contains("money") {
            return .finance
        } else if simplified.contains("creat") || simplified.contains("art") {
            return .creativity
        }
        
        return .health // Default to health
    }
    
    static func parseAnalysisResponse(_ responseText: String) -> PersonalizedAnalysis? {
        print("Attempting to parse response text of length: \(responseText.count)")
        
        // Step 1: Fix common JSON formatting issues
        var cleanedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix syntax errors in JSON that might occur in the API response
        
        // Fix missing commas between array elements (e.g., "} {" should be "},{")
        cleanedText = cleanedText.replacingOccurrences(of: "\\}\\s*\\{", with: "},{", options: .regularExpression)
        
        // Fix JSON with extra commas before closing brackets (e.g., "[1,2,]" should be "[1,2]")
        cleanedText = cleanedText.replacingOccurrences(of: ",\\s*\\]", with: "]", options: .regularExpression)
        
        // Try direct decoding first
        do {
            let data = cleanedText.data(using: .utf8)!
            let decoder = JSONDecoder()
            
            // Modified to use our custom decoding
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
            
            struct TempAnalysis: Decodable {
                let insights: [TempInsight]
                let recommendations: [TempRecommendation]
                let evidenceLinks: [EvidenceLink]?
            }
            
            // Try to decode with error tolerance
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let tempAnalysis = try decoder.decode(TempAnalysis.self, from: data)
            
            // Create and convert insights
            let insights = tempAnalysis.insights.map { tempInsight -> Insight in
                return Insight(
                    title: tempInsight.title,
                    description: tempInsight.description,
                    focusArea: mapFocusArea(tempInsight.focusArea),
                    severity: InsightSeverity.fromString(tempInsight.severity)
                )
            }
            
            // Convert recommendations
            let recommendations = tempAnalysis.recommendations.map { tempRec -> Recommendation in
                return Recommendation(
                    title: tempRec.title,
                    description: tempRec.description,
                    focusArea: mapFocusArea(tempRec.focusArea),
                    impact: RecommendationImpact.fromString(tempRec.impact),
                    timeframe: TimeFrame.fromString(tempRec.timeframe)
                )
            }
            
            return PersonalizedAnalysis(
                userId: UUID().uuidString,
                generatedAt: Date(),
                insights: insights,
                recommendations: recommendations,
                evidenceLinks: tempAnalysis.evidenceLinks
            )
        } catch {
            print("Direct parsing failed: \(error)")
            
            // Second attempt: Manual JSON fixing for more serious issues
            do {
                // Try to extract valid JSON
                guard let jsonStartIndex = cleanedText.firstIndex(of: "{"),
                      let jsonEndIndex = cleanedText.lastIndex(of: "}") else {
                    print("No JSON content found in response")
                    return nil
                }
                
                let jsonContent = String(cleanedText[jsonStartIndex...jsonEndIndex])
                print("Extracted JSON content prefix: \(jsonContent.prefix(100))...")
                
                // Additional manual fixes for extracted JSON
                var fixedJSON = jsonContent
                
                // Fix the specific issue in your logs - unexpected character in array
                if let range = fixedJSON.range(of: "\"severity\": \"Positive\"\\s*}\\s*\\{", options: .regularExpression) {
                    fixedJSON = fixedJSON.replacingCharacters(in: range, with: "\"severity\": \"Positive\"},{ ")
                }
                
                // Try to decode the fixed JSON
                let fixedData = fixedJSON.data(using: .utf8)!
                let decoder = JSONDecoder()
                
                // Use the same temp structures for consistent handling
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
                
                struct TempAnalysis: Decodable {
                    let insights: [TempInsight]
                    let recommendations: [TempRecommendation]
                    let evidenceLinks: [EvidenceLink]?
                }
                
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let tempAnalysis = try decoder.decode(TempAnalysis.self, from: fixedData)
                
                // Process and return data as before
                let insights = tempAnalysis.insights.map { tempInsight -> Insight in
                    return Insight(
                        title: tempInsight.title,
                        description: tempInsight.description,
                        focusArea: mapFocusArea(tempInsight.focusArea),
                        severity: InsightSeverity.fromString(tempInsight.severity)
                    )
                }
                
                let recommendations = tempAnalysis.recommendations.map { tempRec -> Recommendation in
                    return Recommendation(
                        title: tempRec.title,
                        description: tempRec.description,
                        focusArea: mapFocusArea(tempRec.focusArea),
                        impact: RecommendationImpact.fromString(tempRec.impact),
                        timeframe: TimeFrame.fromString(tempRec.timeframe)
                    )
                }
                
                return PersonalizedAnalysis(
                    userId: UUID().uuidString,
                    generatedAt: Date(),
                    insights: insights,
                    recommendations: recommendations,
                    evidenceLinks: tempAnalysis.evidenceLinks
                )
            } catch {
                // Final fallback: Create a minimal valid analysis
                print("Error parsing extracted JSON: \(error)")
                print("Creating a fallback minimal analysis")
                
                // Create a minimal valid analysis
                let insight = Insight(
                    title: "Default Insight",
                    description: "We couldn't generate a complete analysis. Please try again later.",
                    focusArea: .productivity,
                    severity: .neutral
                )
                
                let recommendation = Recommendation(
                    title: "Try Again Later",
                    description: "Our system is experiencing temporary issues. Please try generating a new analysis in a few minutes.",
                    focusArea: .productivity,
                    impact: .medium,
                    timeframe: .immediate
                )
                
                return PersonalizedAnalysis(
                    userId: UUID().uuidString,
                    generatedAt: Date(),
                    insights: [insight],
                    recommendations: [recommendation],
                    evidenceLinks: []
                )
            }
        }
    }
}
