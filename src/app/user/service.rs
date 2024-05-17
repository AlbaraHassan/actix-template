use actix_web::{web::Data, HttpResponse, Responder};
use log::info;

use crate::core::utils::repository::MongoRepo;

use super::model::User;

pub trait UserServiceTrait {
    async fn get(&self, id: String) -> impl Responder;
    async fn create(&self, data: User) -> impl Responder;
}

pub struct UserService {
    db: MongoRepo<User>,
}


impl UserService{
    pub fn new(db: MongoRepo<User>) -> Self {
        UserService { db }
    }
    pub async fn get(self: &Self,id: String)-> impl Responder{
        match self.db.get_item(&id).await {
            Ok(user) => HttpResponse::Ok().json(user),
            Err(err) => HttpResponse::NotFound().json(err.to_string()),
        }
    }

    pub async fn create(self: &Self, data: User) -> impl Responder{
        match self.db.create_item(data).await {
            Ok(user) => HttpResponse::Ok().json(user),
            Err(err) => HttpResponse::BadRequest().json(err.to_string()),
        }
    }

    // pub async fn get_all(self: &Self) -> impl Responder{
    //     match self.db.get_all().await{
    //         Ok(user)=> HttpResponse::Ok().json(bson::from_bson())
    //     }
    // }
}