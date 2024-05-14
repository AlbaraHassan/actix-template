pub mod user;
use actix_web::web;
use user::controller::config as user_config;

pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.configure(user_config);
}
