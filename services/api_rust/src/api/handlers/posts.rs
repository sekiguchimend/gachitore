use axum::{
    extract::{Multipart, Path, Query, State},
    Extension, Json,
};
use futures::future::join_all;
use image::ImageReader;
use serde::{Deserialize, Serialize};
use std::io::Cursor;
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
// POST /v1/posts/:id/like - toggle like on a post
// GET /v1/posts/:id/comments - list comments for a post
// POST /v1/posts/:id/comments - create a comment
// DELETE /v1/comments/:id - delete own comment
// POST /v1/comments/:id/like - toggle like on a comment
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
    pub avatar_url: Option<String>,
    pub content: String,
    pub image_url: Option<String>,
    pub thumbnail_url: Option<String>,
    pub created_at: String,
    pub like_count: i64,
    pub comment_count: i64,
    pub is_liked: bool,
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
    crate::api::validation::validate_uuid(&user.user_id)?;

    let limit = q.limit.unwrap_or(50).clamp(1, 100);
    let offset = q.offset.unwrap_or(0).max(0);

    // Get blocked user IDs (users that current user has blocked)
    let blocked_query = format!("blocker_user_id=eq.{}&select=blocked_user_id", user.user_id);
    let blocked_users: Vec<BlockedUserId> = state
        .supabase
        .select("user_blocks", &blocked_query, &user.token)
        .await
        .unwrap_or_default();
    let blocked_ids: HashSet<String> = blocked_users.into_iter().map(|b| b.blocked_user_id).collect();

    // Fetch posts with user profile join (include avatar_path)
    let query = format!(
        "select=*,user_profiles(display_name,avatar_path)&order=created_at.desc&limit={}&offset={}",
        limit, offset
    );

    let posts: Vec<PostWithProfile> = state
        .supabase
        .select("posts", &query, &user.token)
        .await?;

    // Filter out posts from blocked users
    let posts: Vec<PostWithProfile> = posts
        .into_iter()
        .filter(|p| !blocked_ids.contains(&p.user_id))
        .collect();

    // Fetch like counts, comment counts, and user's likes for each post
    let post_ids: Vec<String> = posts.iter().map(|p| p.id.clone()).collect();
    
    // Get like counts
    let like_counts = get_post_like_counts(&state, &post_ids, &user.token).await;
    
    // Get comment counts
    let comment_counts = get_post_comment_counts(&state, &post_ids, &user.token).await;
    
    // Get user's likes
    let user_likes = get_user_post_likes(&state, &post_ids, &user.user_id, &user.token).await;

    // Fetch signed URLs for images, thumbnails, and avatars in parallel
    let url_futures: Vec<_> = posts
        .iter()
        .map(|p| {
            let state = &state;
            let token = &user.token;
            async move {
                // Image URL (original)
                let image_url = if let Some(ref path) = p.image_path {
                    state
                        .supabase
                        .get_signed_url("user-photos", path, 3600, token)
                        .await
                        .ok()
                } else {
                    None
                };

                // Thumbnail URL (for fast list loading)
                let thumbnail_url = if let Some(ref path) = p.image_path {
                    let thumb_path = get_thumbnail_path(path);
                    state
                        .supabase
                        .get_signed_url("user-photos", &thumb_path, 3600, token)
                        .await
                        .ok()
                } else {
                    None
                };

                // Avatar URL
                let avatar_url = if let Some(ref profile) = p.user_profiles {
                    if let Some(ref avatar_path) = profile.avatar_path {
                        state
                            .supabase
                            .get_signed_url("user-photos", avatar_path, 3600, token)
                            .await
                            .ok()
                    } else {
                        None
                    }
                } else {
                    None
                };

                (image_url, thumbnail_url, avatar_url)
            }
        })
        .collect();

    let urls: Vec<(Option<String>, Option<String>, Option<String>)> = join_all(url_futures).await;

    let items: Vec<PostItemResponse> = posts
        .into_iter()
        .zip(urls)
        .map(|(p, (image_url, thumbnail_url, avatar_url))| {
            let like_count = like_counts.get(&p.id).copied().unwrap_or(0);
            let comment_count = comment_counts.get(&p.id).copied().unwrap_or(0);
            let is_liked = user_likes.contains(&p.id);
            
            PostItemResponse {
                id: p.id.clone(),
                user_id: p.user_id.clone(),
                display_name: p.user_profiles
                    .map(|up| up.display_name)
                    .unwrap_or_else(|| "匿名".to_string()),
                avatar_url,
                content: p.content,
                image_url,
                thumbnail_url,
                created_at: p.created_at,
                like_count,
                comment_count,
                is_liked,
            }
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
    crate::api::validation::validate_uuid(&user.user_id)?;

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

    // Upload image if provided (with thumbnail generation)
    let image_path = if let Some(bytes) = image_bytes {
        if bytes.len() > 10 * 1024 * 1024 {
            return Err(AppError::BadRequest("image is too large (max 10MB)".to_string()));
        }

        let (ext, validated_content_type) = validate_image_magic_bytes(&bytes)?;
        let object_id = Uuid::new_v4().to_string();
        let object_path = format!("{}/{}.{}", user.user_id, object_id, ext);

        // Generate thumbnail (400px width, JPEG for speed)
        let thumbnail_bytes = generate_thumbnail(&bytes, 400)?;
        let thumbnail_path = format!("{}/{}_thumb.jpg", user.user_id, object_id);

        // Upload original and thumbnail in parallel
        let (original_result, thumbnail_result) = tokio::join!(
            state.supabase.upload_object(
                "user-photos",
                &object_path,
                bytes,
                &validated_content_type,
                &user.token
            ),
            state.supabase.upload_object(
                "user-photos",
                &thumbnail_path,
                thumbnail_bytes,
                "image/jpeg",
                &user.token
            )
        );

        original_result?;
        // Thumbnail failure is non-critical, just log it
        if let Err(e) = thumbnail_result {
            tracing::warn!("Failed to upload thumbnail: {}", e);
        }

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

    // Get signed URLs for image and thumbnail
    let (image_url, thumbnail_url) = if let Some(ref path) = created.image_path {
        let thumb_path = get_thumbnail_path(path);
        let (img, thumb) = tokio::join!(
            state.supabase.get_signed_url("user-photos", path, 3600, &user.token),
            state.supabase.get_signed_url("user-photos", &thumb_path, 3600, &user.token)
        );
        (img.ok(), thumb.ok())
    } else {
        (None, None)
    };

    // Get user's display name and avatar
    let profile_query = format!("user_id=eq.{}&select=display_name,avatar_path", user.user_id);
    let profiles: Vec<UserProfileMinimal> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await
        .unwrap_or_default();

    let profile = profiles.first();
    let display_name = profile
        .map(|p| p.display_name.clone())
        .unwrap_or_else(|| "匿名".to_string());

    // Get avatar URL
    let avatar_url = if let Some(p) = profile {
        if let Some(ref avatar_path) = p.avatar_path {
            state
                .supabase
                .get_signed_url("user-photos", avatar_path, 3600, &user.token)
                .await
                .ok()
        } else {
            None
        }
    } else {
        None
    };

    Ok(Json(CreatePostResponse {
        post: PostItemResponse {
            id: created.id,
            user_id: created.user_id,
            display_name,
            avatar_url,
            content: created.content,
            image_url,
            thumbnail_url,
            created_at: created.created_at,
            like_count: 0,
            comment_count: 0,
            is_liked: false,
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
    // Validate IDs
    crate::api::validation::validate_uuid(&post_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;

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
    pub avatar_path: Option<String>,
}

#[derive(Debug, Deserialize)]
struct BlockedUserId {
    blocked_user_id: String,
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

/// Generate a thumbnail from image bytes (resized to max_width, JPEG output)
fn generate_thumbnail(bytes: &[u8], max_width: u32) -> AppResult<Vec<u8>> {
    let reader = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()
        .map_err(|e| AppError::BadRequest(format!("画像の読み込みに失敗しました: {}", e)))?;

    let img = reader
        .decode()
        .map_err(|e| AppError::BadRequest(format!("画像のデコードに失敗しました: {}", e)))?;

    // Only resize if wider than max_width
    let resized = if img.width() > max_width {
        img.thumbnail(max_width, max_width * 2) // Maintain aspect ratio
    } else {
        img
    };

    // Encode as JPEG (quality 80 - good balance of size/quality)
    let mut output = Cursor::new(Vec::new());
    resized
        .write_to(&mut output, image::ImageFormat::Jpeg)
        .map_err(|e| AppError::BadRequest(format!("サムネイル生成に失敗しました: {}", e)))?;

    Ok(output.into_inner())
}

/// Get thumbnail path from original image path
fn get_thumbnail_path(original_path: &str) -> String {
    // "user_id/uuid.jpg" -> "user_id/uuid_thumb.jpg"
    if let Some(dot_pos) = original_path.rfind('.') {
        format!("{}_thumb.jpg", &original_path[..dot_pos])
    } else {
        format!("{}_thumb.jpg", original_path)
    }
}

// =============================================================================
// Like/Comment Helper Functions
// =============================================================================

use std::collections::{HashMap, HashSet};

/// Get like counts for multiple posts
async fn get_post_like_counts(
    state: &AppState,
    post_ids: &[String],
    token: &str,
) -> HashMap<String, i64> {
    let mut counts = HashMap::new();
    if post_ids.is_empty() {
        return counts;
    }

    // Validate all post IDs before building query
    if crate::api::validation::validate_uuids(post_ids).is_err() {
        return counts; // Return empty on invalid IDs (defensive)
    }

    // Query likes grouped by post_id
    let ids_str = post_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
    let query = format!("post_id=in.({})&select=post_id", ids_str);
    
    if let Ok(likes) = state.supabase.select::<PostLikeMinimal>("post_likes", &query, token).await {
        for like in likes {
            *counts.entry(like.post_id).or_insert(0) += 1;
        }
    }

    counts
}

/// Get comment counts for multiple posts
async fn get_post_comment_counts(
    state: &AppState,
    post_ids: &[String],
    token: &str,
) -> HashMap<String, i64> {
    let mut counts = HashMap::new();
    if post_ids.is_empty() {
        return counts;
    }

    if crate::api::validation::validate_uuids(post_ids).is_err() {
        return counts;
    }

    let ids_str = post_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
    let query = format!("post_id=in.({})&select=post_id", ids_str);

    if let Ok(comments) = state.supabase.select::<PostCommentMinimal>("post_comments", &query, token).await {
        for comment in comments {
            *counts.entry(comment.post_id).or_insert(0) += 1;
        }
    }

    counts
}

/// Get post IDs that the user has liked
async fn get_user_post_likes(
    state: &AppState,
    post_ids: &[String],
    user_id: &str,
    token: &str,
) -> HashSet<String> {
    let mut liked = HashSet::new();
    if post_ids.is_empty() {
        return liked;
    }

    if crate::api::validation::validate_uuids(post_ids).is_err() || crate::api::validation::validate_uuid(user_id).is_err() {
        return liked;
    }

    let ids_str = post_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
    let query = format!("post_id=in.({})&user_id=eq.{}&select=post_id", ids_str, user_id);

    if let Ok(likes) = state.supabase.select::<PostLikeMinimal>("post_likes", &query, token).await {
        for like in likes {
            liked.insert(like.post_id);
        }
    }

    liked
}

#[derive(Debug, Deserialize)]
struct PostLikeMinimal {
    post_id: String,
}

#[derive(Debug, Deserialize)]
struct PostCommentMinimal {
    post_id: String,
}

// =============================================================================
// POST /v1/posts/:id/like - Toggle like on a post
// =============================================================================

#[derive(Debug, Serialize)]
pub struct LikeResponse {
    pub liked: bool,
    pub like_count: i64,
}

pub async fn toggle_post_like(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(post_id): Path<String>,
) -> AppResult<Json<LikeResponse>> {
    crate::api::validation::validate_uuid(&post_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;

    // Check if already liked
    let check_query = format!("post_id=eq.{}&user_id=eq.{}&select=id", post_id, user.user_id);
    let existing: Vec<IdOnly> = state
        .supabase
        .select("post_likes", &check_query, &user.token)
        .await
        .unwrap_or_default();

    let liked = if existing.is_empty() {
        // Add like
        let insert_data = serde_json::json!({
            "post_id": post_id,
            "user_id": user.user_id,
        });
        let _: serde_json::Value = state.supabase.insert("post_likes", &insert_data, &user.token).await?;
        true
    } else {
        // Remove like
        let delete_query = format!("post_id=eq.{}&user_id=eq.{}", post_id, user.user_id);
        state.supabase.delete("post_likes", &delete_query, &user.token).await?;
        false
    };

    // Get updated count
    let count_query = format!("post_id=eq.{}&select=id", post_id);
    let count_result: Vec<IdOnly> = state
        .supabase
        .select("post_likes", &count_query, &user.token)
        .await
        .unwrap_or_default();

    Ok(Json(LikeResponse {
        liked,
        like_count: count_result.len() as i64,
    }))
}

#[derive(Debug, Deserialize)]
struct IdOnly {
    #[allow(dead_code)]
    id: String,
}

// =============================================================================
// GET /v1/posts/:id/comments - List comments for a post
// POST /v1/posts/:id/comments - Create a comment
// =============================================================================

#[derive(Debug, Serialize)]
pub struct CommentItemResponse {
    pub id: String,
    pub post_id: String,
    pub user_id: String,
    pub display_name: String,
    pub avatar_url: Option<String>,
    pub content: String,
    pub reply_to_user_id: Option<String>,
    pub reply_to_display_name: Option<String>,
    pub created_at: String,
    pub like_count: i64,
    pub is_liked: bool,
}

#[derive(Debug, Serialize)]
pub struct ListCommentsResponse {
    pub comments: Vec<CommentItemResponse>,
}

#[derive(Debug, Serialize)]
pub struct CreateCommentResponse {
    pub comment: CommentItemResponse,
}

#[derive(Debug, Deserialize)]
pub struct ListCommentsQuery {
    pub limit: Option<i32>,
    pub offset: Option<i32>,
}

pub async fn list_comments(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(post_id): Path<String>,
    Query(q): Query<ListCommentsQuery>,
) -> AppResult<Json<ListCommentsResponse>> {
    crate::api::validation::validate_uuid(&post_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;

    let limit = q.limit.unwrap_or(50).clamp(1, 100);
    let offset = q.offset.unwrap_or(0).max(0);

    // Fetch comments with user profile
    let query = format!(
        "post_id=eq.{}&select=*,user_profiles!post_comments_user_id_user_profiles_fkey(display_name,avatar_path)&order=created_at.desc&limit={}&offset={}",
        post_id, limit, offset
    );

    let comments: Vec<CommentWithProfile> = state
        .supabase
        .select("post_comments", &query, &user.token)
        .await?;

    // Get reply_to display names separately if needed
    let reply_to_user_ids: Vec<String> = comments
        .iter()
        .filter_map(|c| c.reply_to_user_id.clone())
        .collect();

    let reply_to_names: std::collections::HashMap<String, String> = if !reply_to_user_ids.is_empty() {
        let ids_str = reply_to_user_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
        let reply_query = format!("user_id=in.({})&select=user_id,display_name", ids_str);
        if let Ok(profiles) = state.supabase.select::<UserProfileWithUserId>("user_profiles", &reply_query, &user.token).await {
            profiles.into_iter().map(|p| (p.user_id, p.display_name)).collect()
        } else {
            std::collections::HashMap::new()
        }
    } else {
        std::collections::HashMap::new()
    };

    // Get comment IDs for like counts
    let comment_ids: Vec<String> = comments.iter().map(|c| c.id.clone()).collect();
    let like_counts = get_comment_like_counts(&state, &comment_ids, &user.token).await;
    let user_likes = get_user_comment_likes(&state, &comment_ids, &user.user_id, &user.token).await;

    // Get avatar URLs
    let avatar_futures: Vec<_> = comments
        .iter()
        .map(|c| {
            let state = &state;
            let token = &user.token;
            async move {
                if let Some(ref profile) = c.user_profiles {
                    if let Some(ref avatar_path) = profile.avatar_path {
                        return state
                            .supabase
                            .get_signed_url("user-photos", avatar_path, 3600, token)
                            .await
                            .ok();
                    }
                }
                None
            }
        })
        .collect();

    let avatar_urls: Vec<Option<String>> = join_all(avatar_futures).await;

    let items: Vec<CommentItemResponse> = comments
        .into_iter()
        .zip(avatar_urls)
        .map(|(c, avatar_url)| {
            let like_count = like_counts.get(&c.id).copied().unwrap_or(0);
            let is_liked = user_likes.contains(&c.id);
            let reply_to_display_name = c.reply_to_user_id.as_ref()
                .and_then(|uid| reply_to_names.get(uid).cloned());

            CommentItemResponse {
                id: c.id.clone(),
                post_id: c.post_id,
                user_id: c.user_id,
                display_name: c.user_profiles
                    .map(|up| up.display_name)
                    .unwrap_or_else(|| "匿名".to_string()),
                avatar_url,
                content: c.content,
                reply_to_user_id: c.reply_to_user_id.clone(),
                reply_to_display_name,
                created_at: c.created_at,
                like_count,
                is_liked,
            }
        })
        .collect();

    Ok(Json(ListCommentsResponse { comments: items }))
}

#[derive(Debug, Deserialize)]
pub struct CreateCommentRequest {
    pub content: String,
    pub reply_to_user_id: Option<String>,
}

pub async fn create_comment(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(post_id): Path<String>,
    Json(req): Json<CreateCommentRequest>,
) -> AppResult<Json<CreateCommentResponse>> {
    crate::api::validation::validate_uuid(&post_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;
    if let Some(ref reply_to) = req.reply_to_user_id {
        crate::api::validation::validate_uuid(reply_to)?;
    }

    // Validate content
    if req.content.trim().is_empty() {
        return Err(AppError::BadRequest("content cannot be empty".to_string()));
    }
    if req.content.chars().count() > 500 {
        return Err(AppError::BadRequest("content is too long (max 500 chars)".to_string()));
    }

    // Verify post exists
    let post_query = format!("id=eq.{}&select=id", post_id);
    let posts: Vec<IdOnly> = state
        .supabase
        .select("posts", &post_query, &user.token)
        .await?;

    if posts.is_empty() {
        return Err(AppError::NotFound("Post not found".to_string()));
    }

    // Insert comment
    let insert_data = serde_json::json!({
        "post_id": post_id,
        "user_id": user.user_id,
        "content": req.content,
        "reply_to_user_id": req.reply_to_user_id,
    });

    let created: CommentRecord = state
        .supabase
        .insert("post_comments", &insert_data, &user.token)
        .await?;

    // Get user's display name and avatar
    let profile_query = format!("user_id=eq.{}&select=display_name,avatar_path", user.user_id);
    let profiles: Vec<UserProfileMinimal> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await
        .unwrap_or_default();

    let profile = profiles.first();
    let display_name = profile
        .map(|p| p.display_name.clone())
        .unwrap_or_else(|| "匿名".to_string());

    let avatar_url = if let Some(p) = profile {
        if let Some(ref avatar_path) = p.avatar_path {
            state
                .supabase
                .get_signed_url("user-photos", avatar_path, 3600, &user.token)
                .await
                .ok()
        } else {
            None
        }
    } else {
        None
    };

    // Get reply_to display name if applicable
    let reply_to_display_name = if let Some(ref reply_to_id) = req.reply_to_user_id {
        let reply_query = format!("user_id=eq.{}&select=display_name", reply_to_id);
        let reply_profiles: Vec<UserProfileMinimal> = state
            .supabase
            .select("user_profiles", &reply_query, &user.token)
            .await
            .unwrap_or_default();
        reply_profiles.first().map(|p| p.display_name.clone())
    } else {
        None
    };

    Ok(Json(CreateCommentResponse {
        comment: CommentItemResponse {
            id: created.id,
            post_id: created.post_id,
            user_id: created.user_id,
            display_name,
            avatar_url,
            content: created.content,
            reply_to_user_id: created.reply_to_user_id,
            reply_to_display_name,
            created_at: created.created_at,
            like_count: 0,
            is_liked: false,
        },
    }))
}

#[derive(Debug, Deserialize)]
struct CommentRecord {
    id: String,
    post_id: String,
    user_id: String,
    content: String,
    reply_to_user_id: Option<String>,
    created_at: String,
}

#[derive(Debug, Deserialize)]
struct CommentWithProfile {
    id: String,
    post_id: String,
    user_id: String,
    content: String,
    reply_to_user_id: Option<String>,
    created_at: String,
    user_profiles: Option<UserProfileMinimal>,
}

#[derive(Debug, Deserialize)]
struct UserProfileWithUserId {
    user_id: String,
    display_name: String,
}

// =============================================================================
// DELETE /v1/comments/:id - Delete own comment
// =============================================================================

#[derive(Debug, Serialize)]
pub struct DeleteCommentResponse {
    pub success: bool,
}

pub async fn delete_comment(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(comment_id): Path<String>,
) -> AppResult<Json<DeleteCommentResponse>> {
    crate::api::validation::validate_uuid(&comment_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;

    // Delete the comment (RLS ensures only owner can delete)
    let delete_query = format!("id=eq.{}&user_id=eq.{}", comment_id, user.user_id);
    state.supabase.delete("post_comments", &delete_query, &user.token).await?;

    Ok(Json(DeleteCommentResponse { success: true }))
}

// =============================================================================
// POST /v1/comments/:id/like - Toggle like on a comment
// =============================================================================

pub async fn toggle_comment_like(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(comment_id): Path<String>,
) -> AppResult<Json<LikeResponse>> {
    crate::api::validation::validate_uuid(&comment_id)?;
    crate::api::validation::validate_uuid(&user.user_id)?;

    // Check if already liked
    let check_query = format!("comment_id=eq.{}&user_id=eq.{}&select=id", comment_id, user.user_id);
    let existing: Vec<IdOnly> = state
        .supabase
        .select("comment_likes", &check_query, &user.token)
        .await
        .unwrap_or_default();

    let liked = if existing.is_empty() {
        // Add like
        let insert_data = serde_json::json!({
            "comment_id": comment_id,
            "user_id": user.user_id,
        });
        let _: serde_json::Value = state.supabase.insert("comment_likes", &insert_data, &user.token).await?;
        true
    } else {
        // Remove like
        let delete_query = format!("comment_id=eq.{}&user_id=eq.{}", comment_id, user.user_id);
        state.supabase.delete("comment_likes", &delete_query, &user.token).await?;
        false
    };

    // Get updated count
    let count_query = format!("comment_id=eq.{}&select=id", comment_id);
    let count_result: Vec<IdOnly> = state
        .supabase
        .select("comment_likes", &count_query, &user.token)
        .await
        .unwrap_or_default();

    Ok(Json(LikeResponse {
        liked,
        like_count: count_result.len() as i64,
    }))
}

/// Get like counts for multiple comments
async fn get_comment_like_counts(
    state: &AppState,
    comment_ids: &[String],
    token: &str,
) -> HashMap<String, i64> {
    let mut counts = HashMap::new();
    if comment_ids.is_empty() {
        return counts;
    }

    if crate::api::validation::validate_uuids(comment_ids).is_err() {
        return counts;
    }

    let ids_str = comment_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
    let query = format!("comment_id=in.({})&select=comment_id", ids_str);
    
    if let Ok(likes) = state.supabase.select::<CommentLikeMinimal>("comment_likes", &query, token).await {
        for like in likes {
            *counts.entry(like.comment_id).or_insert(0) += 1;
        }
    }

    counts
}

/// Get comment IDs that the user has liked
async fn get_user_comment_likes(
    state: &AppState,
    comment_ids: &[String],
    user_id: &str,
    token: &str,
) -> HashSet<String> {
    let mut liked = HashSet::new();
    if comment_ids.is_empty() {
        return liked;
    }

    if crate::api::validation::validate_uuids(comment_ids).is_err() || crate::api::validation::validate_uuid(user_id).is_err() {
        return liked;
    }

    let ids_str = comment_ids.iter().map(|id| format!("\"{}\"", id)).collect::<Vec<_>>().join(",");
    let query = format!("comment_id=in.({})&user_id=eq.{}&select=comment_id", ids_str, user_id);
    
    if let Ok(likes) = state.supabase.select::<CommentLikeMinimal>("comment_likes", &query, token).await {
        for like in likes {
            liked.insert(like.comment_id);
        }
    }

    liked
}

#[derive(Debug, Deserialize)]
struct CommentLikeMinimal {
    comment_id: String,
}

