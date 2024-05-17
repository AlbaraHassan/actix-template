use std::any::Any;

use actix_web::web::{self, Data};

use crate::{app::user::{model::User, service::UserService}, core::utils::repository::MongoRepo};
use crate::app::user::controller::config as user_controller;


pub async fn config_services() -> Data<UserService>{
    Data::new(UserService::new(MongoRepo::<User>::init().await))
}



pub fn config_controllers(cfg: &mut web::ServiceConfig) {
    cfg.configure(user_controller);
}