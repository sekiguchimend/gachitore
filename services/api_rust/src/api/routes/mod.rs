use axum::{
    middleware,
    routing::{delete, get, patch, post},
    Router,
};

use crate::api::{handlers, middleware::auth_middleware};
use crate::AppState;

/// Create all API routes
pub fn create_routes(state: AppState) -> Router<AppState> {
    Router::new()
        // Health check
        .route("/health", get(health_check))
        // Auth endpoints (no auth required)
        .nest("/auth", auth_routes())
        // Protected routes (auth required)
        .nest("/users", users_routes(state.clone()))
        .nest("/meals", meals_routes(state.clone()))
        .nest("/exercises", exercises_routes(state.clone()))
        .nest("/workouts", workouts_routes(state.clone()))
        .nest("/dashboard", dashboard_routes(state.clone()))
        .nest("/log", log_routes(state.clone()))
        .nest("/ai", ai_routes(state.clone()))
}

/// Health check endpoint
async fn health_check() -> &'static str {
    "OK"
}

/// POST /v1/auth/* routes (no auth middleware)
fn auth_routes() -> Router<AppState> {
    Router::new()
        .route("/signup", post(handlers::signup))
        .route("/signin", post(handlers::signin))
        .route("/signout", post(handlers::signout))
        .route("/refresh", post(handlers::refresh_token))
        .route("/password/reset", post(handlers::reset_password))
}

/// /v1/users/* routes (auth required)
fn users_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/profile", get(handlers::get_profile).patch(handlers::update_profile))
        .route("/onboarding/status", get(handlers::get_onboarding_status))
        .route("/onboarding/complete", post(handlers::complete_onboarding))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// /v1/meals/* routes (auth required)
fn meals_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/", get(handlers::get_meals))
        .route("/nutrition", get(handlers::get_nutrition))
        .route("/:id", delete(handlers::delete_meal))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// /v1/exercises/* routes (auth required)
fn exercises_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/", get(handlers::get_exercises))
        .route("/stats", get(handlers::get_exercises_with_stats))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// /v1/workouts/* routes (auth required)
fn workouts_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/", get(handlers::get_workouts))
        .route("/:id", get(handlers::get_workout_detail))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// /v1/dashboard/* routes (auth required)
fn dashboard_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/today", get(handlers::get_dashboard))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// /v1/log/* routes (auth required) - for logging data
fn log_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/workout", post(handlers::log_workout))
        .route("/meal", post(handlers::log_meal))
        .route("/metrics", post(handlers::log_metrics))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

/// POST /v1/ai/* routes (auth required)
fn ai_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/ask", post(handlers::ask_ai))
        .route("/plan/today", post(handlers::plan_today))
        .route("/history", get(handlers::get_ai_history))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}
