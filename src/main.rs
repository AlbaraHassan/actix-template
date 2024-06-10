mod app;
mod core;

use actix_web::{middleware::Logger, App, HttpServer};
use app::app_config::{ config_controllers, config_services};
use core::logger::init_logger;
use std::io::Result;
use log::{info};

#[actix_web::main]
async fn main() -> Result<()> {
    init_logger();
    let services = config_services().await;
    info!("Server started at http://127.0.0.1:8080");
    HttpServer::new(move || {
        App::new()
            .app_data(services.clone())
            .configure(config_controllers)
            .wrap(Logger::default())
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
