use log::info;
use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize, Serializer};

#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    pub id: Option<ObjectId>,
    pub username: String,
    pub email: String,
    #[serde(serialize_with = "hash_password")]
    pub password: String,
}

fn hash_password<S>(password: &String, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let hashed_password = hash_function(password);
    hashed_password.serialize(serializer)
}

fn hash_function(password: &String) -> String {
    format!("hashed({})", password)
}
