use revolt_database::{Database, User};
use revolt_models::v0;
use revolt_result::{create_error, Result};
use rocket::serde::json::Json;
use rocket::State;
use revolt_rocket_okapi::openapi;

/// # Search Users
///
/// Search for users by username or display name
#[openapi(tag = "Users")]
#[get("/search?<query>&<limit>")]
pub async fn search_users(
    db: &State<Database>,
    user: User,
    query: Option<String>,
    limit: Option<i64>,
) -> Result<Json<Vec<v0::User>>> {
    if user.bot.is_some() {
        return Err(create_error!(IsBot));
    }

    let query = query.unwrap_or_default();
    
    // Ensure query is at least 2 characters to prevent spam
    if query.len() < 2 {
        return Ok(Json(vec![]));
    }

    let limit = limit.unwrap_or(20).min(50); // Max 50 results

    // Search for users by username or display name (case insensitive)
    let users = db
        .fetch_users_by_username_or_display_name(&query, limit)
        .await?;

    let mut result = Vec::new();
    for found_user in users {
        if found_user.id != user.id {
            // Exclude the searching user
            result.push(found_user.into_self(false).await);
        }
    }

    Ok(Json(result))
}