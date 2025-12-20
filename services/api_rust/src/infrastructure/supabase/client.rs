use reqwest::{Client, StatusCode};
use serde::{de::DeserializeOwned, Serialize};

use crate::error::{AppError, AppResult};

#[derive(Debug, serde::Deserialize)]
struct PostgrestErrorBody {
    #[allow(dead_code)]
    code: Option<String>,
    #[allow(dead_code)]
    details: Option<serde_json::Value>,
    #[allow(dead_code)]
    hint: Option<String>,
    message: Option<String>,
}

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

    fn map_postgrest_error(&self, context: &str, status: StatusCode, body: String) -> AppError {
        // Most PostgREST errors are JSON: {"code": "...", "details": ..., "hint": ..., "message": "..."}
        // If it's client-side (400 etc), treat it as a user-facing bad request instead of 502.
        if status.is_client_error() {
            if let Ok(parsed) = serde_json::from_str::<PostgrestErrorBody>(&body) {
                if let Some(msg) = parsed.message {
                    return AppError::BadRequest(format!("{}: {}", context, msg));
                }
            }
            return AppError::BadRequest(format!("{}: {}", context, body));
        }

        AppError::SupabaseError(format!("{}: {} - {}", context, status, body))
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
            return Err(self.map_postgrest_error("SELECT failed", status, body));
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
                Err(self.map_postgrest_error("SELECT single failed", status, body))
            }
        }
    }

    /// Count rows for a given filter query.
    ///
    /// This uses PostgREST `Prefer: count=exact` and parses the `Content-Range` header.
    /// `query` should NOT include `select=...` (this method will add `select=id`).
    pub async fn count(&self, table: &str, query: &str, access_token: &str) -> AppResult<i64> {
        let query_part = if query.trim().is_empty() {
            "select=id".to_string()
        } else {
            format!("{}&select=id", query)
        };
        let url = format!("{}/{}?{}", self.rest_url(), table, query_part);

        let response = self
            .client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", access_token))
            .header("Prefer", "count=exact")
            // Return at most 1 row; we only care about Content-Range total
            .header("Range", "0-0")
            .header("Content-Type", "application/json")
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(self.map_postgrest_error("COUNT failed", status, body));
        }

        let content_range = response
            .headers()
            .get("content-range")
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| AppError::SupabaseError("COUNT missing Content-Range header".to_string()))?;

        // Example: "0-0/123" or "*/0"
        let total_part = content_range
            .split('/')
            .nth(1)
            .ok_or_else(|| AppError::SupabaseError("Invalid Content-Range header".to_string()))?;

        if total_part == "*" {
            return Ok(0);
        }

        let total: i64 = total_part.parse().map_err(|_| {
            AppError::SupabaseError(format!("Invalid Content-Range total: {}", content_range))
        })?;

        Ok(total)
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
            return Err(self.map_postgrest_error("INSERT failed", status, body));
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
            return Err(self.map_postgrest_error("INSERT batch failed", status, body));
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
            return Err(self.map_postgrest_error("UPDATE failed", status, body));
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
            .header("Prefer", "resolution=merge-duplicates,return=minimal")
            .query(&[("on_conflict", on_conflict)])
            .json(data)
            .send()
            .await?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(self.map_postgrest_error("UPSERT failed", status, body));
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
            return Err(self.map_postgrest_error("DELETE failed", status, body));
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
            return Err(self.map_postgrest_error(&format!("RPC {} failed", function), status, body));
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

        #[derive(serde::Deserialize)]
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
        } else if signed_url.starts_with("/storage/v1") {
            Ok(format!("{}{}", self.base_url, signed_url))
        } else {
            // Supabase returns "/object/sign/..." without "/storage/v1" prefix
            Ok(format!("{}/storage/v1{}", self.base_url, signed_url))
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



