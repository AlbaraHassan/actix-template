use serde::{self, Deserialize};

#[derive(Deserialize)]
pub struct GetOneUser {
    pub id: String,
}
