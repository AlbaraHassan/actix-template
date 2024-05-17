use mongodb::bson::{doc, oid::ObjectId, Bson, Document};

use crate::app::user::model::User;

fn user_to_document(user: &User) -> Document {
    let User {
        id,
        username,
        email,
        password,
    } = user;
    doc! {
        "id": id,
        "username": username,
        "email": email,
        "password": password
    }
}

fn build_user(
    id: Option<ObjectId>,
    username: String,
    email: String,
    password: String,
) -> User {
    User {
        id,
        username,
        email,
        password
    }
}


fn user_from_document(document: Document) -> User {
    let mut _username = "".to_string();
    let mut _email = "".to_string();
    let mut _password = "".to_string();
    let mut _id = ObjectId::new();
    if let Some(&Bson::String(ref username)) = document.get("username") {
        _username = username.to_string();
    }
    if let Some(&Bson::String(ref password)) = document.get("password") {
        _password = password.to_string();
    }
    if let Some(&Bson::String(ref email)) = document.get("email") {
        _email = email.to_string();
    }
    if let Some(&Bson::ObjectId(ref id)) = document.get("_id") {
        _id = *id;
    }

 build_user(Some(_id), _username, _email, _password)
}