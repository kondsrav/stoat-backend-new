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
#[get("/search")]
pub async fn search_users(
    db: &State<Database>,
    user: User,
) -> Result<Json<Vec<v0::User>>> {
    if user.bot.is_some() {
        return Err(create_error!(IsBot));
    }

    // For now, just return all users except the current one (for testing)
    let all_users = db.fetch_users().await?;
    
    let mut result = Vec::new();
    for found_user in all_users {
        if found_user.id != user.id && result.len() < 10 {
            // Exclude the searching user and limit to 10
            result.push(found_user.into_self(false).await);
        }
    }

    Ok(Json(result))
}