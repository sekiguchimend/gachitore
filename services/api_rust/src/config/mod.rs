use std::env;

/// Application configuration loaded from environment variables
#[derive(Debug, Clone)]
pub struct Config {
    // Server
    pub host: String,
    pub port: u16,

    // CORS - allowed origins (comma-separated list)
    pub allowed_origins: Vec<String>,

    // Supabase (anon key only - RLS enabled)
    pub supabase_url: String,
    pub supabase_anon_key: String,
    /// Legacy JWT secret (HS256). Optional when using signing keys (ES256/RS256 + JWKS).
    pub supabase_jwt_secret: String,
    /// JWKS URL for verifying access tokens signed with asymmetric keys (ES256/RS256).
    pub supabase_jwks_url: String,

    // Gemini
    pub gemini_api_key: String,
    pub gemini_model: String,
}

impl Config {
    /// Load configuration from environment variables
    pub fn from_env() -> anyhow::Result<Self> {
        // Parse CORS allowed origins from comma-separated list
        let allowed_origins = env::var("ALLOWED_ORIGINS")
            .unwrap_or_else(|_| "http://localhost:3000".to_string())
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        let supabase_url = env::var("SUPABASE_URL")
            .map_err(|_| anyhow::anyhow!("SUPABASE_URL is required"))?;
        let supabase_url_trimmed = supabase_url.trim_end_matches('/').to_string();
        let supabase_jwks_url = env::var("SUPABASE_JWKS_URL").unwrap_or_else(|_| {
            format!("{}/auth/v1/.well-known/jwks.json", supabase_url_trimmed)
        });

        Ok(Self {
            // Server
            host: env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            port: env::var("PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()?,

            // CORS
            allowed_origins,

            // Supabase (anon key only)
            supabase_url,
            supabase_anon_key: env::var("SUPABASE_ANON_KEY")
                .map_err(|_| anyhow::anyhow!("SUPABASE_ANON_KEY is required"))?,
            // Optional: when using signing keys, this may not be available/needed.
            supabase_jwt_secret: env::var("SUPABASE_JWT_SECRET").unwrap_or_default(),
            supabase_jwks_url,

            // Gemini
            gemini_api_key: env::var("GEMINI_API_KEY")
                .map_err(|_| anyhow::anyhow!("GEMINI_API_KEY is required"))?,
            gemini_model: env::var("GEMINI_MODEL")
                .unwrap_or_else(|_| "gemini-1.5-flash".to_string()),
        })
    }
}
