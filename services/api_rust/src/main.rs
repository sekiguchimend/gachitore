mod api;
mod config;
mod domain;
mod error;
mod infrastructure;
mod state;

use crate::config::Config;
use crate::infrastructure::gemini::GeminiClient;
use crate::infrastructure::supabase::SupabaseClient;
use axum::Router;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::RwLock;
use axum::http::{header, HeaderValue, Method};
use tower_http::cors::CorsLayer;
use tower_http::catch_panic::CatchPanicLayer;
use tower_http::trace::TraceLayer;
use tower_http::set_header::SetResponseHeaderLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use tower_governor::GovernorLayer;
use tower_governor::governor::GovernorConfigBuilder;

/// Application state shared across handlers
#[derive(Clone)]
pub struct AppState {
    pub supabase: SupabaseClient,
    pub gemini: GeminiClient,
    pub config: Arc<Config>,
    pub jwks_cache: Arc<RwLock<Option<api::middleware::CachedJwks>>>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env file
    dotenvy::dotenv().ok();

    // Ensure panics are logged (otherwise a panic can look like a "mysterious 500")
    std::panic::set_hook(Box::new(|info| {
        // Always print to stderr too (in case log filter hides tracing output)
        eprintln!("panic: {info}");
        let bt = std::backtrace::Backtrace::force_capture();
        eprintln!("backtrace:\n{bt}");
        tracing::error!("panic: {}", info);
        tracing::error!("backtrace: {}", bt);
    }));

    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,gachitore_api=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    let config = Config::from_env()?;
    let addr = SocketAddr::new(config.host.parse()?, config.port);

    tracing::info!(
        "Starting Gachitore API server... version={} env_filter={}",
        env!("CARGO_PKG_VERSION"),
        std::env::var("RUST_LOG").unwrap_or_else(|_| "(default)".to_string())
    );

    // Initialize Supabase client (anon key only - RLS enabled)
    let supabase = SupabaseClient::new(&config.supabase_url, &config.supabase_anon_key);
    tracing::info!("Supabase client initialized (anon key + RLS)");

    // Initialize Gemini client
    let gemini = GeminiClient::new(&config.gemini_api_key, &config.gemini_model);
    tracing::info!("Gemini client initialized");

    // Create application state
    let state = AppState {
        supabase,
        gemini,
        config: Arc::new(config),
        jwks_cache: Arc::new(RwLock::new(None)),
    };

    // Build CORS layer with restricted origins
    // SECURITY (CSRF Protection): This API uses JWT Bearer authentication via Authorization header
    // instead of cookies, which provides inherent CSRF protection because:
    // 1. Browsers do not automatically send Authorization headers (unlike cookies)
    // 2. Attackers cannot read/write the JWT token from a different origin
    // 3. CORS policy below enforces allowed origins for cross-origin requests
    // Therefore, traditional CSRF tokens are not required for this mobile API.
    let origins: Vec<_> = state
        .config
        .allowed_origins
        .iter()
        .filter_map(|origin| origin.parse().ok())
        .collect();

    // Security warning: Check if CORS is properly configured for production
    let is_localhost_only = state
        .config
        .allowed_origins
        .iter()
        .all(|o| o.contains("localhost") || o.contains("127.0.0.1"));

    let has_production_origin = state
        .config
        .allowed_origins
        .iter()
        .any(|o| !o.contains("localhost") && !o.contains("127.0.0.1"));

    // SECURITY: Validate CORS configuration before starting server
    if origins.is_empty() {
        tracing::error!("CRITICAL: No valid CORS origins configured. API will reject all cross-origin requests.");
        return Err(anyhow::anyhow!("Invalid CORS configuration: no valid origins"));
    }

    // Log detailed CORS configuration
    tracing::info!("CORS configuration:");
    tracing::info!("  - Allowed origins: {:?}", state.config.allowed_origins);
    tracing::info!("  - Total valid origins: {}", origins.len());
    tracing::info!("  - Localhost only: {}", is_localhost_only);
    tracing::info!("  - Has production origins: {}", has_production_origin);

    // Production environment check
    let environment = std::env::var("ENVIRONMENT").unwrap_or_else(|_| "development".to_string());
    if environment == "production" && !has_production_origin {
        tracing::error!(
            "CRITICAL: Production environment detected but no production CORS origins configured!"
        );
        tracing::error!(
            "Set ALLOWED_ORIGINS environment variable with production domains."
        );
        return Err(anyhow::anyhow!("Invalid CORS configuration for production"));
    }

    if is_localhost_only {
        tracing::warn!(
            "CORS is configured for localhost only. Set ALLOWED_ORIGINS for production deployment."
        );
    }

    let cors = CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::PATCH,
            Method::DELETE,
        ])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::ACCEPT,
        ])
        .allow_credentials(true);

    // Configure rate limiting
    // General API: 100 requests per second per IP
    let governor_conf = GovernorConfigBuilder::default()
        .per_second(100)
        .burst_size(200)
        .finish()
        .expect("Failed to create rate limiter config");

    let rate_limit_layer = GovernorLayer {
        config: Arc::new(governor_conf),
    };

    tracing::info!("Rate limiting enabled: 100 req/s per IP, burst: 200");

    // Build router with security headers
    let app = Router::new()
        .nest("/v1", api::routes::create_routes(state.clone()))
        .layer(rate_limit_layer)
        // Catch panics and turn them into 500 *with a guaranteed panic+backtrace log*
        .layer(CatchPanicLayer::new())
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        // Security headers
        .layer(SetResponseHeaderLayer::if_not_present(
            header::X_CONTENT_TYPE_OPTIONS,
            HeaderValue::from_static("nosniff"),
        ))
        .layer(SetResponseHeaderLayer::if_not_present(
            header::X_FRAME_OPTIONS,
            HeaderValue::from_static("DENY"),
        ))
        .layer(SetResponseHeaderLayer::if_not_present(
            header::REFERRER_POLICY,
            HeaderValue::from_static("strict-origin-when-cross-origin"),
        ))
        .layer(SetResponseHeaderLayer::if_not_present(
            header::HeaderName::from_static("x-xss-protection"),
            HeaderValue::from_static("1; mode=block"),
        ))
        // Content Security Policy: Lock down resources to prevent XSS
        .layer(SetResponseHeaderLayer::if_not_present(
            header::CONTENT_SECURITY_POLICY,
            HeaderValue::from_static("default-src 'none'; frame-ancestors 'none'"),
        ))
        // HSTS: Force HTTPS for 1 year with subdomains
        .layer(SetResponseHeaderLayer::if_not_present(
            header::STRICT_TRANSPORT_SECURITY,
            HeaderValue::from_static("max-age=31536000; includeSubDomains; preload"),
        ))
        // Permissions Policy: Disable sensitive browser features
        .layer(SetResponseHeaderLayer::if_not_present(
            header::HeaderName::from_static("permissions-policy"),
            HeaderValue::from_static("camera=(), microphone=(), geolocation=(), payment=()"),
        ))
        .with_state(state);

    tracing::info!("Security headers enabled: X-Content-Type-Options, X-Frame-Options, Referrer-Policy, X-XSS-Protection, CSP, HSTS, Permissions-Policy");

    // Start server
    tracing::info!("Listening on {}", addr);
    let listener = TcpListener::bind(addr).await?;
    // Required for tower_governor (rate limiting) to extract the client IP.
    // Without this, GovernorLayer fails with "Unable To Extract Key!" and returns 500 for all requests.
    axum::serve(listener, app.into_make_service_with_connect_info::<SocketAddr>()).await?;

    Ok(())
}
