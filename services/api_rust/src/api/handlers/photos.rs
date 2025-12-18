use axum::{
    extract::{Multipart, Query, State},
    Extension, Json,
};
use futures::future::join_all;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    infrastructure::supabase::UserPhoto,
    AppState,
};

// =============================================================================
// GET /v1/photos - list user's photos
// POST /v1/photos - upload a photo (multipart)
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct ListPhotosQuery {
    pub limit: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct PhotoItemResponse {
    pub id: String,
    pub created_at: String,
    pub image_url: String,
}

#[derive(Debug, Serialize)]
pub struct ListPhotosResponse {
    pub photos: Vec<PhotoItemResponse>,
}

#[derive(Debug, Serialize)]
pub struct UploadPhotoResponse {
    pub photo: PhotoItemResponse,
}

pub async fn list_photos(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(q): Query<ListPhotosQuery>,
) -> AppResult<Json<ListPhotosResponse>> {
    let limit = q.limit.unwrap_or(60).clamp(1, 200);
    let query = format!(
        "user_id=eq.{}&select=*&order=created_at.desc&limit={}",
        user.user_id, limit
    );

    let photos: Vec<UserPhoto> = state
        .supabase
        .select("user_photos", &query, &user.token)
        .await?;

    // Fetch signed URLs in parallel for better scalability
    let url_futures: Vec<_> = photos
        .iter()
        .map(|p| {
            state
                .supabase
                .get_signed_url(&p.bucket_id, &p.object_path, 3600, &user.token)
        })
        .collect();

    let urls = join_all(url_futures).await;

    let items: Vec<PhotoItemResponse> = photos
        .into_iter()
        .zip(urls)
        .filter_map(|(p, url_result)| {
            url_result.ok().map(|url| PhotoItemResponse {
                id: p.id,
                created_at: p.created_at,
                image_url: url,
            })
        })
        .collect();

    Ok(Json(ListPhotosResponse { photos: items }))
}

pub async fn upload_photo(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    mut multipart: Multipart,
) -> AppResult<Json<UploadPhotoResponse>> {
    // Expect a single file field: "file"
    let mut bytes: Option<Vec<u8>> = None;
    let mut content_type: Option<String> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("Invalid multipart: {}", e)))?
    {
        if field.name() != Some("file") {
            continue;
        }

        content_type = field
            .content_type()
            .map(|ct| ct.to_string())
            .or_else(|| Some("image/jpeg".to_string()));

        let data = field
            .bytes()
            .await
            .map_err(|e| AppError::BadRequest(format!("Failed to read file: {}", e)))?;
        bytes = Some(data.to_vec());
        break;
    }

    let bytes = bytes.ok_or_else(|| AppError::BadRequest("file is required".to_string()))?;
    let content_type = content_type.unwrap_or_else(|| "image/jpeg".to_string());

    if bytes.is_empty() {
        return Err(AppError::BadRequest("file is empty".to_string()));
    }
    // Hard limit: 10MB
    if bytes.len() > 10 * 1024 * 1024 {
        return Err(AppError::BadRequest("file is too large (max 10MB)".to_string()));
    }

    let ext = match content_type.as_str() {
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "jpg",
    };

    let object_id = Uuid::new_v4().to_string();
    let object_path = format!("{}/{}.{}", user.user_id, object_id, ext);
    let bucket_id = "user-photos";

    // Upload to storage
    state
        .supabase
        .upload_object(bucket_id, &object_path, bytes, &content_type, &user.token)
        .await?;

    // Insert metadata row
    let insert_data = serde_json::json!({
        "user_id": user.user_id,
        "bucket_id": bucket_id,
        "object_path": object_path,
        "taken_at": chrono::Utc::now().to_rfc3339(),
        "meta": {},
    });

    let created: UserPhoto = state
        .supabase
        .insert("user_photos", &insert_data, &user.token)
        .await?;

    let url = state
        .supabase
        .get_signed_url(&created.bucket_id, &created.object_path, 3600, &user.token)
        .await?;

    Ok(Json(UploadPhotoResponse {
        photo: PhotoItemResponse {
            id: created.id,
            created_at: created.created_at,
            image_url: url,
        },
    }))
}


