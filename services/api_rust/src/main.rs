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
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

/// Application state shared across handlers
#[derive(Clone)]
pub struct AppState {
    pub supabase: SupabaseClient,
    pub gemini: GeminiClient,
    pub config: Arc<Config>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Load .env file
    dotenvy::dotenv().ok();

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

    tracing::info!("Starting Gachitore API server...");

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
    };

    // Build CORS layer
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build router
    let app = Router::new()
        .nest("/v1", api::routes::create_routes(state.clone()))
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state);

    // Start server
    tracing::info!("Listening on {}", addr);
    let listener = TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
