mod upload;

pub use upload::*;

use revolt_rocket_okapi::revolt_okapi::openapi3::OpenApi;

pub fn routes() -> (Vec<rocket::Route>, OpenApi) {
    openapi_get_routes_spec![upload_attachment, download_attachment, download_attachment_sized]
}

