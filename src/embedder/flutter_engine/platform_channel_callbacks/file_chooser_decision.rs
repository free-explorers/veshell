use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::portal::service::{handle_file_chooser_decision, ConsentOutcome};
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct FileChooserDecisionPayload {
    consent_token: u64,
    outcome: PromptOutcomePayload,
    #[serde(default)]
    uris: Vec<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
enum PromptOutcomePayload {
    Approved,
    Cancelled,
}

pub fn file_chooser_decision<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: FileChooserDecisionPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_file_chooser_payload".to_string(),
                    format!("File chooser decision payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    handle_file_chooser_decision(
        data,
        payload.consent_token,
        payload.outcome.into(),
        payload.uris,
    );
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
