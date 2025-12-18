use reqwest::{Client, StatusCode};
use serde::{de::DeserializeOwned, Deserialize, Serialize};

use crate::error::{AppError, AppResult};

/// Supabase REST API client
/// Uses anon key + user access token for RLS
#[derive(Clone)]
pub struct SupabaseClient {
    client: Client,
    base_url: String,
    anon_key: String,
}

impl SupabaseClient {
    pub fn new(supabase_url: &str, anon_key: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: supabase_url.to_string(),
            anon_key: anon_key.to_string(),
        }
    }

    /// REST API base URL
    fn rest_url(&self) -> String {
        format!("{}/rest/v1", self.base_url)
    }

    /// Execute a SELECT query on a table
    /// `access_token` is the user's JWT from Flutter (enables RLS)
    pub async fn select<T: DeserializeOwned>(
        &self,
        table: &str,
        query: &str,
        access_token: &str,
    ) -> AppResult<Vec<T>> {
        let url = format!("{}/{}?{}", self.rest_url(), table, query);

        let response = self
            .client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "SELECT failed: {} - {}",
                status, body
            )));
        }

        let data = response.json::<Vec<T>>().await?;
        Ok(data)
    }

    /// Execute a SELECT query expecting a single result
    pub async fn select_single<T: DeserializeOwned>(
        &self,
        table: &str,
        query: &str,
        access_token: &str,
    ) -> AppResult<Option<T>> {
        let url = format!("{}/{}?{}", self.rest_url(), table, query);

        let response = self
            .client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Accept", "application/vnd.pgrst.object+json")
            .header("Content-Type", "application/json")
            .send()
            .await?;

        match response.status() {
            StatusCode::OK => {
                let data = response.json::<T>().await?;
                Ok(Some(data))
            }
            StatusCode::NOT_ACCEPTABLE => {
                // No rows found
                Ok(None)
            }
            status => {
                let body = response.text().await.unwrap_or_default();
                Err(AppError::SupabaseError(format!(
                    "SELECT single failed: {} - {}",
                    status, body
                )))
            }
        }
    }

    /// Execute an INSERT
    pub async fn insert<T: Serialize, R: DeserializeOwned>(
        &self,
        table: &str,
        data: &T,
        access_token: &str,
    ) -> AppResult<R> {
        let url = format!("{}/{}", self.rest_url(), table);

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .header("Prefer", "return=representation")
            .json(data)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "INSERT failed: {} - {}",
                status, body
            )));
        }

        let result: Vec<R> = response.json().await?;
        result
            .into_iter()
            .next()
            .ok_or_else(|| AppError::SupabaseError("No data returned from INSERT".to_string()))
    }

    /// Execute a batch INSERT (multiple rows at once)
    pub async fn insert_batch<T: Serialize>(
        &self,
        table: &str,
        data: &[T],
        access_token: &str,
    ) -> AppResult<()> {
        if data.is_empty() {
            return Ok(());
        }

        let url = format!("{}/{}", self.rest_url(), table);

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .header("Prefer", "return=minimal")
            .json(data)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "INSERT batch failed: {} - {}",
                status, body
            )));
        }

        Ok(())
    }

    /// Execute an UPDATE
    pub async fn update<T: Serialize>(
        &self,
        table: &str,
        query: &str,
        data: &T,
        access_token: &str,
    ) -> AppResult<()> {
        let url = format!("{}/{}?{}", self.rest_url(), table, query);

        let response = self
            .client
            .patch(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .json(data)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "UPDATE failed: {} - {}",
                status, body
            )));
        }

        Ok(())
    }

    /// Execute an UPSERT (insert or update on conflict)
    pub async fn upsert<T: Serialize>(
        &self,
        table: &str,
        data: &T,
        on_conflict: &str,
        access_token: &str,
    ) -> AppResult<()> {
        let url = format!("{}/{}", self.rest_url(), table);

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .header("Prefer", format!("resolution=merge-duplicates,return=minimal"))
            .query(&[("on_conflict", on_conflict)])
            .json(data)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "UPSERT failed: {} - {}",
                status, body
            )));
        }

        Ok(())
    }

    /// Execute a DELETE
    pub async fn delete(&self, table: &str, query: &str, access_token: &str) -> AppResult<()> {
        let url = format!("{}/{}?{}", self.rest_url(), table, query);

        let response = self
            .client
            .delete(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "DELETE failed: {} - {}",
                status, body
            )));
        }

        Ok(())
    }

    /// Call an RPC function
    pub async fn rpc<T: Serialize, R: DeserializeOwned>(
        &self,
        function: &str,
        params: &T,
        access_token: &str,
    ) -> AppResult<R> {
        let url = format!("{}/rpc/{}", self.rest_url(), function);

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", "application/json")
            .json(params)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "RPC {} failed: {} - {}",
                function, status, body
            )));
        }

        let result = response.json::<R>().await?;
        Ok(result)
    }

    /// Get a signed URL for a storage object (uses anon key)
    pub async fn get_signed_url(
        &self,
        bucket: &str,
        path: &str,
        expires_in: i32,
        access_token: &str,
    ) -> AppResult<String> {
        let url = format!(
            "{}/storage/v1/object/sign/{}/{}",
            self.base_url, bucket, path
        );

        #[derive(Serialize)]
        struct SignRequest {
            #[serde(rename = "expiresIn")]
            expires_in: i32,
        }

        #[derive(Deserialize)]
        struct SignResponse {
            #[serde(rename = "signedURL")]
            signed_url: String,
        }

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .json(&SignRequest { expires_in })
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "Storage API error: {} - {}",
                status, body
            )));
        }

        let sign_response: SignResponse = response.json().await?;
        let signed_url = sign_response.signed_url;
        if signed_url.starts_with("http://") || signed_url.starts_with("https://") {
            Ok(signed_url)
        } else {
            Ok(format!("{}{}", self.base_url, signed_url))
        }
    }

    /// Upload an object to Supabase Storage (uses anon key + user JWT for RLS)
    pub async fn upload_object(
        &self,
        bucket: &str,
        path: &str,
        bytes: Vec<u8>,
        content_type: &str,
        access_token: &str,
    ) -> AppResult<()> {
        let url = format!(
            "{}/storage/v1/object/{}/{}",
            self.base_url, bucket, path
        );

        let response = self
            .client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Content-Type", content_type)
            .header("x-upsert", "true")
            .body(bytes)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "Storage upload error: {} - {}",
                status, body
            )));
        }

        Ok(())
    }

    /// Delete an object from Supabase Storage (uses anon key + user JWT for RLS)
    pub async fn delete_object(
        &self,
        bucket: &str,
        path: &str,
        access_token: &str,
    ) -> AppResult<()> {
        let url = format!(
            "{}/storage/v1/object/{}/{}",
            self.base_url, bucket, path
        );

        let response = self
            .client
            .delete(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(AppError::SupabaseError(format!(
                "Storage delete error: {} - {}",
                status, body
            )));
        }

        Ok(())
    }
}

// =============================================================================
// Data models for Supabase responses
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    pub user_id: String,
    pub display_name: String,
    pub sex: Option<String>,
    pub birth_year: Option<i32>,
    pub height_cm: Option<i32>,
    pub training_level: String,
    pub goal: String,
    pub environment: Option<serde_json::Value>,
    pub constraints: Option<serde_json::Value>,
    pub meals_per_day: Option<i32>,
    pub onboarding_completed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BodyMetrics {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NutritionDaily {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub calories: i32,
    pub protein_g: f64,
    pub fat_g: f64,
    pub carbs_g: f64,
    pub fiber_g: Option<f64>,
    pub meals_logged: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Workout {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub perceived_fatigue: Option<i32>,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkoutExercise {
    pub id: String,
    pub workout_id: String,
    pub exercise_id: Option<String>,
    pub custom_exercise_name: Option<String>,
    pub muscle_tag: String,
    pub exercise_order: i32,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkoutSet {
    pub id: String,
    pub workout_exercise_id: String,
    pub set_index: i32,
    pub weight_kg: Option<f64>,
    pub reps: Option<i32>,
    pub rpe: Option<f64>,
    pub rest_sec: Option<i32>,
    pub tempo: Option<String>,
    pub is_warmup: bool,
    pub is_dropset: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiSession {
    pub id: String,
    pub user_id: String,
    pub intent: String,
    pub state_version: String,
    pub model: String,
    pub input_summary: Option<serde_json::Value>,
    pub safety_flags: serde_json::Value,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiMessage {
    pub id: String,
    pub session_id: String,
    pub role: String,
    pub content: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserPhoto {
    pub id: String,
    pub user_id: String,
    pub bucket_id: String,
    pub object_path: String,
    pub taken_at: Option<String>,
    pub created_at: String,
    pub meta: Option<serde_json::Value>,
}
