use crate::helpers::TestApp;

// Tokio's test macro is used to run the test in an async environment
#[tokio::test]
async fn root_returns_auth_ui() {
    let app = TestApp::new().await;

    let response = app.get_root().await;

    assert_eq!(response.status().as_u16(), 200);
    assert_eq!(response.headers().get("content-type").unwrap(), "text/html");
}

// TODO: Implement tests for all other routes (signup, login, logout, verify-2fa, and verify-token)
// For now, simply assert that each route returns a 200 HTTP status code.
#[tokio::test]
async fn post_signup() {
    let app = TestApp::new().await;
    let response = app.post_signup().await;
    assert_eq!(response.status().as_u16(), 200);
}
#[tokio::test]
async fn post_login() {
    let app = TestApp::new().await;
    let response = app.post_login().await;
    assert_eq!(response.status().as_u16(), 200);
}
#[tokio::test]
async fn post_logout() {
    let app = TestApp::new().await;
    let response = app.post_logout().await;
    assert_eq!(response.status().as_u16(), 200);
}
#[tokio::test]
async fn post_verify_2fa() {
    let app = TestApp::new().await;
    let response = app.post_verify_2fa().await;
    assert_eq!(response.status().as_u16(), 200);
}
#[tokio::test]
async fn post_verify_token() {
    let app = TestApp::new().await;
    let response = app.post_verify_token().await;
    assert_eq!(response.status().as_u16(), 200);
}
