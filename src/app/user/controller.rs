use crate::{
    app::user::{model::User, service::UserService, types::GetOneUser},
    core::utils::repository::MongoRepo,
};
use actix_web::{
    get, post,
    web::{self, Data, Json, Query},
    HttpResponse, Responder,
};
use log::info;

#[get("/")]
pub async fn get(service: Data<UserService>, new_user: Query<GetOneUser>) -> impl Responder {
    service.get(new_user.id.clone()).await
}

#[post("/")]
pub async fn create(service: Data<UserService>, new_user: Json<User>) -> impl Responder {
    service
        .create(User {
            id: None,
            username: new_user.username.to_owned(),
            email: new_user.email.to_owned(),
            password: new_user.password.to_owned(),
        })
        .await
}

pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(web::scope("/user").service(create).service(get));
}
