use dotenv::dotenv;
use mongodb::{
    bson::{doc, extjson::de::Error, oid::ObjectId},
    results::InsertOneResult,
    Client, Collection,
};
use serde::{de::DeserializeOwned, Serialize};
use std::env;

pub trait MongoRepoTraits: Serialize + DeserializeOwned + Unpin + Send + Sync {}
impl<T: Serialize + DeserializeOwned + Unpin + Send + Sync> MongoRepoTraits for T {}

pub struct MongoRepo<T> {
    col: Collection<T>, //No need for it to be in Arc Since Data<T> uses Arc
}

impl<T> MongoRepo<T>
where
    T: MongoRepoTraits,
{
    pub async fn init() -> Self {
        dotenv().ok();
        let uri = match env::var("DATABASE_URL") {
            Ok(v) => v.to_string(),
            Err(_) => format!("Error loading env variable"),
        };
        let client = Client::with_uri_str(uri).await.unwrap();
        let db = client.database("rustDB");
        let col: Collection<T> = db.collection("user");
        MongoRepo { col }
    }

    pub async fn create_item(&self, item: T) -> Result<InsertOneResult, Error> {
        let result = self.col.insert_one(item, None).await;
        Ok(result.unwrap())
    }

    pub async fn get_item(&self, id: &String) -> Result<Option<T>, Error> {
        let filter = doc! {"_id": ObjectId::parse_str(id).unwrap()};
        let item = self.col.find_one(filter, None).await;
        Ok(item.unwrap())
    }
}
