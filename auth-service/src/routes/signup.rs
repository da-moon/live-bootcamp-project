use axum::{http::StatusCode, response::IntoResponse, Json};
use getset::{CloneGetters, CopyGetters, Getters, MutGetters, Setters, WithSetters};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct Request {
    pub email: String,
    pub password: String,
    pub requires2FA: bool,
}
// TODO: maybe change it to an enum
#[derive(Serialize)]
pub struct SuccessResponse {
    pub message: String,
}
// TODO return success response type
pub async fn signup(request: Json<Request>) -> impl IntoResponse {
    StatusCode::OK.into_response()
    // Success Case:
    // Status code: 201
    // Message: User created successfully
}

// '400':
//   description: Invalid input
//   content:
//     application/json:
//       schema:
//         type: object
//         properties:
//           error:
//             type: string
// '409':
//   description: Email already exists
//   content:
//     application/json:
//       schema:
//         type: object
//         properties:
//           error:
//             type: string
// '422':
//   description: Unprocessable content
// '500':
//   description: Unexpected error
//   content:
//     application/json:
//       schema:
//         type: object
//         properties:
//           error:
//             type: string
