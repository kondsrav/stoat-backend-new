// use revolt_database::util::reference::Reference;
use revolt_database::{Database, User, AMQP, RelationshipStatus};
use revolt_models::v0;
use revolt_result::{create_error, Result};
use rocket::serde::json::Json;
use rocket::State;

/// # Send Friend Request (with Auto-Accept)
///
/// Send a friend request to another user and automatically accept it from both sides.
#[openapi(tag = "Relationships")]
#[post("/friend", data = "<data>")]
pub async fn send_friend_request(
    db: &State<Database>,
    amqp: &State<AMQP>,
    mut user: User,
    data: Json<v0::DataSendFriendRequest>,
) -> Result<Json<v0::User>> {
    if let Some((username, discriminator)) = data.username.split_once('#') {
        let mut target = db.fetch_user_by_username(username, discriminator).await?;

        if user.bot.is_some() || target.bot.is_some() {
            return Err(create_error!(IsBot));
        }

        // Check current relationship status
        let current_relationship = user.relationship_with(&target.id);

        match current_relationship {
            RelationshipStatus::None => {
                // Auto-accept: Instead of just sending request, make them friends immediately
                user.apply_relationship(
                    db,
                    &mut target,
                    RelationshipStatus::Friend,
                    RelationshipStatus::Friend,
                )
                .await?;

                // Send notification that friend request was auto-accepted
                _ = amqp.friend_request_accepted(&user, &target).await;
            }
            RelationshipStatus::Incoming => {
                // If target already sent us a request, accept it normally
                user.add_friend(db, amqp, &mut target).await?;
            }
            _ => {
                // For other cases (already friends, already sent, blocked, etc.)
                // Use the existing logic
                user.add_friend(db, amqp, &mut target).await?;
            }
        }

        Ok(Json(target.into(db, &user).await))
    } else {
        Err(create_error!(InvalidProperty))
    }
}
