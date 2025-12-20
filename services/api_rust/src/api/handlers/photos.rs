use axum::{
    extract::{Multipart, Path, Query, State},
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
    const MAX_PHOTOS_PER_USER: i64 = 100;

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

    if bytes.is_empty() {
        return Err(AppError::BadRequest("file is empty".to_string()));
    }
    // Hard limit: 10MB
    if bytes.len() > 10 * 1024 * 1024 {
        return Err(AppError::BadRequest("file is too large (max 10MB)".to_string()));
    }

    // Validate actual image format using magic bytes (security: don't trust Content-Type header)
    let (ext, validated_content_type) = validate_image_magic_bytes(&bytes)?;

    // Enforce per-user photo limit (backend)
    let current_count = state
        .supabase
        .count("user_photos", &format!("user_id=eq.{}", user.user_id), &user.token)
        .await?;
    if current_count >= MAX_PHOTOS_PER_USER {
        return Err(AppError::Validation(
            "写真は1人100枚までです。不要な写真を削除してください。".to_string(),
        ));
    }

    let content_type = validated_content_type;

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

// =============================================================================
// DELETE /v1/photos/:id - delete a photo
// =============================================================================

#[derive(Debug, Serialize)]
pub struct DeletePhotoResponse {
    pub success: bool,
}

pub async fn delete_photo(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(photo_id): Path<String>,
) -> AppResult<Json<DeletePhotoResponse>> {
    // First, fetch the photo record to get bucket_id and object_path
    let query = format!("id=eq.{}&user_id=eq.{}&select=*", photo_id, user.user_id);
    let photos: Vec<UserPhoto> = state
        .supabase
        .select("user_photos", &query, &user.token)
        .await?;

    let photo = photos
        .into_iter()
        .next()
        .ok_or_else(|| AppError::NotFound("Photo not found".to_string()))?;

    // Delete from Storage first
    state
        .supabase
        .delete_object(&photo.bucket_id, &photo.object_path, &user.token)
        .await?;

    // Delete the database record
    let delete_query = format!("id=eq.{}&user_id=eq.{}", photo_id, user.user_id);
    state
        .supabase
        .delete("user_photos", &delete_query, &user.token)
        .await?;

    Ok(Json(DeletePhotoResponse { success: true }))
}

/// Validate image format by checking magic bytes (file signature).
/// Returns (extension, content_type) if valid, or an error if not a supported image format.
fn validate_image_magic_bytes(bytes: &[u8]) -> AppResult<(&'static str, String)> {
    if bytes.len() < 12 {
        return Err(AppError::BadRequest(
            "ファイルが小さすぎます。有効な画像ファイルをアップロードしてください。".to_string(),
        ));
    }

    // JPEG: starts with FF D8 FF
    if bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
        return Ok(("jpg", "image/jpeg".to_string()));
    }

    // PNG: starts with 89 50 4E 47 0D 0A 1A 0A
    if bytes.len() >= 8
        && bytes[0] == 0x89
        && bytes[1] == 0x50
        && bytes[2] == 0x4E
        && bytes[3] == 0x47
        && bytes[4] == 0x0D
        && bytes[5] == 0x0A
        && bytes[6] == 0x1A
        && bytes[7] == 0x0A
    {
        return Ok(("png", "image/png".to_string()));
    }

    // WebP: starts with RIFF....WEBP (bytes 0-3: RIFF, bytes 8-11: WEBP)
    if bytes.len() >= 12
        && bytes[0] == 0x52  // R
        && bytes[1] == 0x49  // I
        && bytes[2] == 0x46  // F
        && bytes[3] == 0x46  // F
        && bytes[8] == 0x57  // W
        && bytes[9] == 0x45  // E
        && bytes[10] == 0x42 // B
        && bytes[11] == 0x50 // P
    {
        return Ok(("webp", "image/webp".to_string()));
    }

    // HEIC/HEIF: ftyp box with heic, heix, mif1, etc.
    if bytes.len() >= 12 && &bytes[4..8] == b"ftyp" {
        let brand = &bytes[8..12];
        if brand == b"heic" || brand == b"heix" || brand == b"mif1" || brand == b"hevc" {
            return Ok(("heic", "image/heic".to_string()));
        }
    }

    Err(AppError::BadRequest(
        "サポートされていない画像形式です。JPEG、PNG、WebP、HEICのいずれかをアップロードしてください。".to_string(),
    ))
}


