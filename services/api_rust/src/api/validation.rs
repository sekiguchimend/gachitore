use chrono::NaiveDate;
use uuid::Uuid;

use crate::error::AppError;

/// Validate date format (YYYY-MM-DD) and return parsed date.
///
/// This is used to prevent PostgREST query injection via `date=eq.<user_input>`.
pub fn validate_date_ymd(date_str: &str) -> Result<NaiveDate, AppError> {
    NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
        .map_err(|_| AppError::Validation("Invalid date format. Expected YYYY-MM-DD".to_string()))
}

/// Validate UUID format.
pub fn validate_uuid(id: &str) -> Result<Uuid, AppError> {
    Uuid::parse_str(id).map_err(|_| AppError::Validation("Invalid ID format".to_string()))
}


