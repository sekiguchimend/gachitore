use reqwest::Client;
use serde::{Deserialize, Serialize};

use crate::error::{AppError, AppResult};

/// Gemini API client
#[derive(Clone)]
pub struct GeminiClient {
    client: Client,
    api_key: String,
    model: String,
}

impl GeminiClient {
    pub fn new(api_key: &str, model: &str) -> Self {
        Self {
            client: Client::new(),
            api_key: api_key.to_string(),
            model: model.to_string(),
        }
    }

    /// Generate content with Gemini API
    pub async fn generate(&self, prompt: &str, system_instruction: Option<&str>) -> AppResult<GeminiResponse> {
        // SECURITY: Use header-based authentication instead of URL parameter to prevent:
        // - API key exposure in HTTP logs
        // - API key leakage via Referer headers
        // - API key exposure in browser history
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent",
            self.model
        );

        let mut contents = vec![Content {
            role: "user".to_string(),
            parts: vec![Part {
                text: prompt.to_string(),
            }],
        }];

        let request = GenerateContentRequest {
            contents,
            system_instruction: system_instruction.map(|s| SystemInstruction {
                parts: vec![Part { text: s.to_string() }],
            }),
            generation_config: Some(GenerationConfig {
                temperature: Some(0.7),
                top_p: Some(0.9),
                top_k: Some(40),
                max_output_tokens: Some(4096),
                response_mime_type: Some("application/json".to_string()),
            }),
            safety_settings: Some(vec![
                SafetySetting {
                    category: "HARM_CATEGORY_HARASSMENT".to_string(),
                    threshold: "BLOCK_MEDIUM_AND_ABOVE".to_string(),
                },
                SafetySetting {
                    category: "HARM_CATEGORY_HATE_SPEECH".to_string(),
                    threshold: "BLOCK_MEDIUM_AND_ABOVE".to_string(),
                },
                SafetySetting {
                    category: "HARM_CATEGORY_SEXUALLY_EXPLICIT".to_string(),
                    threshold: "BLOCK_MEDIUM_AND_ABOVE".to_string(),
                },
                SafetySetting {
                    category: "HARM_CATEGORY_DANGEROUS_CONTENT".to_string(),
                    threshold: "BLOCK_MEDIUM_AND_ABOVE".to_string(),
                },
            ]),
        };

        let response = self
            .client
            .post(&url)
            .header("x-goog-api-key", &self.api_key)
            .json(&request)
            .send()
            .await
            .map_err(|e| AppError::GeminiApi(format!("Request failed: {}", e)))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::GeminiApi(format!(
                "API error: {} - {}",
                status, body
            )));
        }

        let api_response: GenerateContentResponse = response
            .json()
            .await
            .map_err(|e| AppError::GeminiApi(format!("Failed to parse response: {}", e)))?;

        // Extract text from response
        let text = api_response
            .candidates
            .first()
            .and_then(|c| c.content.parts.first())
            .map(|p| p.text.clone())
            .ok_or_else(|| AppError::GeminiApi("Empty response from Gemini".to_string()))?;

        // Parse the JSON response
        let parsed: GeminiResponse = serde_json::from_str(&text)
            .map_err(|e| AppError::GeminiApi(format!("Failed to parse JSON response: {} - Raw: {}", e, text)))?;

        Ok(parsed)
    }

    /// Generate with chat history
    pub async fn generate_with_history(
        &self,
        messages: Vec<ChatMessage>,
        system_instruction: Option<&str>,
    ) -> AppResult<GeminiResponse> {
        // SECURITY: Use header-based authentication (same as generate())
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent",
            self.model
        );

        let contents: Vec<Content> = messages
            .into_iter()
            .map(|m| Content {
                role: m.role,
                parts: vec![Part { text: m.content }],
            })
            .collect();

        let request = GenerateContentRequest {
            contents,
            system_instruction: system_instruction.map(|s| SystemInstruction {
                parts: vec![Part { text: s.to_string() }],
            }),
            generation_config: Some(GenerationConfig {
                temperature: Some(0.7),
                top_p: Some(0.9),
                top_k: Some(40),
                max_output_tokens: Some(4096),
                response_mime_type: Some("application/json".to_string()),
            }),
            safety_settings: None,
        };

        let response = self
            .client
            .post(&url)
            .header("x-goog-api-key", &self.api_key)
            .json(&request)
            .send()
            .await
            .map_err(|e| AppError::GeminiApi(format!("Request failed: {}", e)))?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::GeminiApi(format!(
                "API error: {} - {}",
                status, body
            )));
        }

        let api_response: GenerateContentResponse = response
            .json()
            .await
            .map_err(|e| AppError::GeminiApi(format!("Failed to parse response: {}", e)))?;

        let text = api_response
            .candidates
            .first()
            .and_then(|c| c.content.parts.first())
            .map(|p| p.text.clone())
            .ok_or_else(|| AppError::GeminiApi("Empty response from Gemini".to_string()))?;

        let parsed: GeminiResponse = serde_json::from_str(&text)
            .map_err(|e| AppError::GeminiApi(format!("Failed to parse JSON response: {} - Raw: {}", e, text)))?;

        Ok(parsed)
    }
}

// =============================================================================
// Request/Response types
// =============================================================================

#[derive(Debug, Serialize)]
struct GenerateContentRequest {
    contents: Vec<Content>,
    #[serde(skip_serializing_if = "Option::is_none")]
    system_instruction: Option<SystemInstruction>,
    #[serde(skip_serializing_if = "Option::is_none")]
    generation_config: Option<GenerationConfig>,
    #[serde(skip_serializing_if = "Option::is_none")]
    safety_settings: Option<Vec<SafetySetting>>,
}

#[derive(Debug, Serialize)]
struct SystemInstruction {
    parts: Vec<Part>,
}

#[derive(Debug, Serialize)]
struct Content {
    role: String,
    parts: Vec<Part>,
}

#[derive(Debug, Serialize)]
struct Part {
    text: String,
}

#[derive(Debug, Serialize)]
struct GenerationConfig {
    #[serde(skip_serializing_if = "Option::is_none")]
    temperature: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    top_p: Option<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    top_k: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    max_output_tokens: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    response_mime_type: Option<String>,
}

#[derive(Debug, Serialize)]
struct SafetySetting {
    category: String,
    threshold: String,
}

#[derive(Debug, Deserialize)]
struct GenerateContentResponse {
    candidates: Vec<Candidate>,
}

#[derive(Debug, Deserialize)]
struct Candidate {
    content: CandidateContent,
}

#[derive(Debug, Deserialize)]
struct CandidateContent {
    parts: Vec<CandidatePart>,
}

#[derive(Debug, Deserialize)]
struct CandidatePart {
    text: String,
}

// =============================================================================
// Gemini structured response
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeminiResponse {
    pub answer_text: String,
    #[serde(default)]
    pub recommendations: Vec<Recommendation>,
    #[serde(default)]
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recommendation {
    pub kind: String,
    pub payload: serde_json::Value,
}

#[derive(Debug, Clone)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

impl ChatMessage {
    pub fn user(content: impl Into<String>) -> Self {
        Self {
            role: "user".to_string(),
            content: content.into(),
        }
    }

    pub fn model(content: impl Into<String>) -> Self {
        Self {
            role: "model".to_string(),
            content: content.into(),
        }
    }
}
