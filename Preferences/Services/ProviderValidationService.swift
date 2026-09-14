import Foundation
import SharedSettingsKit

/// Genuine validation service for verifying provider configuration.
///
/// Performs real network verification where safe and supported;
/// never fakes validation results.
public enum ProviderValidationService {
    public enum ValidationResult: Equatable, Sendable {
        case success(message: String)
        case failure(error: String)
        case unsupported(reason: String)

        public var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    public static func validate(
        id: ProviderIdentifier,
        apiKey: String,
        customBaseURL: URL? = nil
    ) async -> ValidationResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(error: "API key is empty.")
        }

        switch id {
        case .openAI:
            let baseURL = customBaseURL ?? URL(string: "https://api.openai.com/v1")!
            let endpoint = baseURL.appendingPathComponent("models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return .success(message: "Successfully connected to OpenAI API.")
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                        return .failure(error: "OpenAI rejected the key: \(errorMsg)")
                    }
                }
                return .failure(error: "Invalid network response.")
            } catch {
                return .failure(error: error.localizedDescription)
            }

        case .gemini:
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
            guard let url = URL(string: urlString) else {
                return .failure(error: "Invalid Gemini URL.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return .success(message: "Successfully verified Google Gemini API key.")
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                        return .failure(error: "Gemini error: \(errorMsg)")
                    }
                }
                return .failure(error: "Invalid network response.")
            } catch {
                return .failure(error: error.localizedDescription)
            }

        case .anthropic:
            let baseURL = customBaseURL ?? URL(string: "https://api.anthropic.com/v1")!
            let endpoint = baseURL.appendingPathComponent("models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return .success(message: "Successfully connected to Anthropic API.")
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                        return .failure(error: "Anthropic error: \(errorMsg)")
                    }
                }
                return .failure(error: "Invalid network response.")
            } catch {
                return .failure(error: error.localizedDescription)
            }

        case .deepSeek:
            let baseURL = customBaseURL ?? URL(string: "https://api.deepseek.com")!
            let endpoint = baseURL.appendingPathComponent("models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return .success(message: "Successfully verified DeepSeek API key.")
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                        return .failure(error: "DeepSeek error: \(errorMsg)")
                    }
                }
                return .failure(error: "Invalid network response.")
            } catch {
                return .failure(error: error.localizedDescription)
            }

        case .groq:
            let baseURL = customBaseURL ?? URL(string: "https://api.groq.com/openai/v1")!
            let endpoint = baseURL.appendingPathComponent("models")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return .success(message: "Successfully verified Groq API key.")
                    } else {
                        let errorMsg = extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
                        return .failure(error: "Groq error: \(errorMsg)")
                    }
                }
                return .failure(error: "Invalid network response.")
            } catch {
                return .failure(error: error.localizedDescription)
            }

        default:
            return .unsupported(
                reason: "Direct live configuration test is not supported for \(id.rawValue). Verify the key in your provider dashboard."
            )
        }
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.prefix(150).description
        }
        if let errorObj = json["error"] as? [String: Any], let message = errorObj["message"] as? String {
            return message
        }
        if let message = json["message"] as? String {
            return message
        }
        return nil
    }
}
