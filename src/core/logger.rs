use env_logger;

pub fn init_logger() {
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Debug)
        .filter_level(log::LevelFilter::Info) // Set log level to debug
        .init();
}
