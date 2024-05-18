use dotenv::dotenv;
use mongodb::{
    bson::{self, bson, doc, extjson::de::Error, oid::ObjectId, Document},
    results::InsertOneResult,
    Client, Collection,
};
use serde::{de::DeserializeOwned, Serialize};
use std::env;
use futures::stream::TryStreamExt;


pub trait MongoRepoTraits:
    Serialize  + DeserializeOwned + Unpin + Send + Sync
{
}
impl<T: Serialize + DeserializeOwned  + Unpin + Send + Sync> MongoRepoTraits for T {}

pub struct MongoRepo<T>
where
    T: MongoRepoTraits,
{
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

    pub async fn get_all(&self) -> Result<Vec<T>, Error> {
        let mut cursor = self.col.find(None, None).await.unwrap();
        let mut data: Vec<T> = Vec::new();
    
        while let Some(doc) = cursor.try_next().await.unwrap() {
            data.push(doc);
        }

        Ok(data)
    }
}
