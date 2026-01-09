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
    infrastructure::supabase::Post,
    AppState,
};

// =============================================================================
// GET /v1/posts - list all posts (latest first)
// POST /v1/posts - create a post (multipart: content + optional image)
// DELETE /v1/posts/:id - delete own post
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct ListPostsQuery {
    pub limit: Option<i32>,
    pub offset: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct PostItemResponse {
    pub id: String,
    pub user_id: String,
    pub display_name: String,
    pub content: String,
    pub image_url: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
pub struct ListPostsResponse {
    pub posts: Vec<PostItemResponse>,
}

#[derive(Debug, Serialize)]
pub struct CreatePostResponse {
    pub post: PostItemResponse,
}

/// List all posts (newest first)
pub async fn list_posts(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(q): Query<ListPostsQuery>,
) -> AppResult<Json<ListPostsResponse>> {
    let limit = q.limit.unwrap_or(50).clamp(1, 100);
    let offset = q.offset.unwrap_or(0).max(0);

    // Fetch posts with user profile join
    let query = format!(
        "select=*,user_profiles(display_name)&order=created_at.desc&limit={}&offset={}",
        limit, offset
    );

    let posts: Vec<PostWithProfile> = state
        .supabase
        .select("posts", &query, &user.token)
        .await?;

    // Fetch signed URLs for images in parallel
    let url_futures: Vec<_> = posts
        .iter()
        .map(|p| async {
            if let Some(ref path) = p.image_path {
                state
                    .supabase
                    .get_signed_url("user-photos", path, 3600, &user.token)
                    .await
                    .ok()
            } else {
                None
            }
        })
        .collect();

    let urls: Vec<Option<String>> = join_all(url_futures).await;

    let items: Vec<PostItemResponse> = posts
        .into_iter()
        .zip(urls)
        .map(|(p, url)| PostItemResponse {
            id: p.id,
            user_id: p.user_id.clone(),
            display_name: p.user_profiles
                .map(|up| up.display_name)
                .unwrap_or_else(|| "匿名".to_string()),
            content: p.content,
            image_url: url,
            created_at: p.created_at,
        })
        .collect();

    Ok(Json(ListPostsResponse { posts: items }))
}

/// Create a new post (with optional image)
pub async fn create_post(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    mut multipart: Multipart,
) -> AppResult<Json<CreatePostResponse>> {
    let mut content: Option<String> = None;
    let mut image_bytes: Option<Vec<u8>> = None;
    let mut image_content_type: Option<String> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::BadRequest(format!("Invalid multipart: {}", e)))?
    {
        let name = field.name().unwrap_or("").to_string();

        match name.as_str() {
            "content" => {
                let text = field
                    .text()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Failed to read content: {}", e)))?;
                content = Some(text);
            }
            "image" => {
                image_content_type = field
                    .content_type()
                    .map(|ct| ct.to_string())
                    .or_else(|| Some("image/jpeg".to_string()));

                let data = field
                    .bytes()
                    .await
                    .map_err(|e| AppError::BadRequest(format!("Failed to read image: {}", e)))?;
                if !data.is_empty() {
                    image_bytes = Some(data.to_vec());
                }
            }
            _ => {}
        }
    }

    let content = content.ok_or_else(|| AppError::BadRequest("content is required".to_string()))?;

    if content.trim().is_empty() {
        return Err(AppError::BadRequest("content cannot be empty".to_string()));
    }
    if content.chars().count() > 1000 {
        return Err(AppError::BadRequest("content is too long (max 1000 chars)".to_string()));
    }

    // Upload image if provided
    let image_path = if let Some(bytes) = image_bytes {
        if bytes.len() > 10 * 1024 * 1024 {
            return Err(AppError::BadRequest("image is too large (max 10MB)".to_string()));
        }

        let (ext, validated_content_type) = validate_image_magic_bytes(&bytes)?;
        let object_id = Uuid::new_v4().to_string();
        let object_path = format!("{}/{}.{}", user.user_id, object_id, ext);

        state
            .supabase
            .upload_object("user-photos", &object_path, bytes, &validated_content_type, &user.token)
            .await?;

        Some(object_path)
    } else {
        None
    };

    // Insert post record
    let insert_data = serde_json::json!({
        "user_id": user.user_id,
        "content": content,
        "image_path": image_path,
    });

    let created: Post = state
        .supabase
        .insert("posts", &insert_data, &user.token)
        .await?;

    // Get signed URL for the image
    let image_url = if let Some(ref path) = created.image_path {
        state
            .supabase
            .get_signed_url("user-photos", path, 3600, &user.token)
            .await
            .ok()
    } else {
        None
    };

    // Get user's display name
    let profile_query = format!("user_id=eq.{}&select=display_name", user.user_id);
    let profiles: Vec<UserProfileMinimal> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await
        .unwrap_or_default();
    let display_name = profiles
        .first()
        .map(|p| p.display_name.clone())
        .unwrap_or_else(|| "匿名".to_string());

    Ok(Json(CreatePostResponse {
        post: PostItemResponse {
            id: created.id,
            user_id: created.user_id,
            display_name,
            content: created.content,
            image_url,
            created_at: created.created_at,
        },
    }))
}

/// Delete own post
#[derive(Debug, Serialize)]
pub struct DeletePostResponse {
    pub success: bool,
}

pub async fn delete_post(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(post_id): Path<String>,
) -> AppResult<Json<DeletePostResponse>> {
    // Fetch the post to get image_path
    let query = format!("id=eq.{}&user_id=eq.{}&select=*", post_id, user.user_id);
    let posts: Vec<Post> = state
        .supabase
        .select("posts", &query, &user.token)
        .await?;

    let post = posts
        .into_iter()
        .next()
        .ok_or_else(|| AppError::NotFound("Post not found".to_string()))?;

    // Delete image from Storage if exists
    if let Some(ref path) = post.image_path {
        let _ = state
            .supabase
            .delete_object("user-photos", path, &user.token)
            .await;
    }

    // Delete the database record
    let delete_query = format!("id=eq.{}&user_id=eq.{}", post_id, user.user_id);
    state
        .supabase
        .delete("posts", &delete_query, &user.token)
        .await?;

    Ok(Json(DeletePostResponse { success: true }))
}

// =============================================================================
// Helper structs
// =============================================================================

#[derive(Debug, Clone, Deserialize)]
struct PostWithProfile {
    pub id: String,
    pub user_id: String,
    pub content: String,
    pub image_path: Option<String>,
    pub created_at: String,
    pub user_profiles: Option<UserProfileMinimal>,
}

#[derive(Debug, Clone, Deserialize)]
struct UserProfileMinimal {
    pub display_name: String,
}

/// Validate image format by checking magic bytes
fn validate_image_magic_bytes(bytes: &[u8]) -> AppResult<(&'static str, String)> {
    if bytes.len() < 12 {
        return Err(AppError::BadRequest(
            "ファイルが小さすぎます。有効な画像ファイルをアップロードしてください。".to_string(),
        ));
    }

    // JPEG
    if bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
        return Ok(("jpg", "image/jpeg".to_string()));
    }

    // PNG
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

    // WebP
    if bytes.len() >= 12
        && bytes[0] == 0x52
        && bytes[1] == 0x49
        && bytes[2] == 0x46
        && bytes[3] == 0x46
        && bytes[8] == 0x57
        && bytes[9] == 0x45
        && bytes[10] == 0x42
        && bytes[11] == 0x50
    {
        return Ok(("webp", "image/webp".to_string()));
    }

    // HEIC/HEIF
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

