use crate::{
    app::user::model::User, app::user::types::GetOneUser, core::utils::repository::MongoRepo,
};
use actix_web::{
    get, post,
    web::{self, Data, Json, Query},
    HttpResponse, Responder,
};

#[get("/")]
pub async fn get(db: Data<MongoRepo<User>>, new_user: Query<GetOneUser>) -> impl Responder {
    match db.get_item(&new_user.id).await {
        Ok(user) => HttpResponse::Ok().json(user),
        Err(err) => HttpResponse::NotFound().json(err.to_string()),
    }
}

#[post("/")]
pub async fn create(db: Data<MongoRepo<User>>, new_user: Json<User>) -> impl Responder {
    let data = User {
        id: None,
        username: new_user.username.to_owned(),
        email: new_user.email.to_owned(),
        password: new_user.password.to_owned(),
    };

    match db.create_item(data).await {
        Ok(user) => HttpResponse::Ok().json(user),
        Err(err) => HttpResponse::BadRequest().json(err.to_string()),
    }
}

pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(web::scope("/user").service(create).service(get));
}
