mod app;
mod core;

use actix_web::{middleware::Logger, web::Data, App, HttpServer};
use app::{config, user::model::User};
use core::{logger::init_logger, utils::repository::MongoRepo};
use std::io::Result;

#[actix_web::main]
async fn main() -> Result<()> {
    init_logger();
    let db = Data::new(MongoRepo::<User>::init().await);
    HttpServer::new(move || {
        App::new()
            .app_data(db.clone())
            .configure(config)
            .wrap(Logger::default())
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
