use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use getset::{CloneGetters, CopyGetters, Getters, MutGetters, Setters, WithSetters};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct Request {
    pub email: String,
    pub password: String,
    #[serde(rename = "requires2FA")]
    pub requires_2fa: bool,
}
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
pub struct Success {
    pub message: String,
}

pub async fn signup(Json(request): Json<Request>) -> impl IntoResponse {
    (
        StatusCode::CREATED,
        Json(Success {
            message: "User created successfully".to_string(),
        }),
    )
}
