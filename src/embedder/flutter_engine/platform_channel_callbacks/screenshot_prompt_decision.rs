use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::portal::service::{handle_screenshot_prompt_decision, ConsentOutcome};
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ScreenshotPromptPayload {
    consent_token: u64,
    outcome: PromptOutcomePayload,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
enum PromptOutcomePayload {
    Approved,
    Cancelled,
}

pub fn screenshot_prompt_decision<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ScreenshotPromptPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_screenshot_prompt_payload".to_string(),
                    format!("Screenshot prompt decision payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    handle_screenshot_prompt_decision(data, payload.consent_token, payload.outcome.into());
    result.success(None);
}

impl From<PromptOutcomePayload> for ConsentOutcome {
    fn from(value: PromptOutcomePayload) -> Self {
        match value {
            PromptOutcomePayload::Approved => ConsentOutcome::Approved,
            PromptOutcomePayload::Cancelled => ConsentOutcome::Cancelled,
        }
    }
}
