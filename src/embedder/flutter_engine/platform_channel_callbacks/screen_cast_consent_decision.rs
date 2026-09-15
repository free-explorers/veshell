use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::portal::service::{handle_consent_decision, ConsentOutcome};
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ConsentDecisionPayload {
    session_handle: String,
    consent_token: u64,
    outcome: ConsentOutcomePayload,
    source_id: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
enum ConsentOutcomePayload {
    Approved,
    Cancelled,
}

pub fn screen_cast_consent_decision<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ConsentDecisionPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_consent_payload".to_string(),
                    format!("Consent decision payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    handle_consent_decision(
        data,
        &payload.session_handle,
        payload.consent_token,
        payload.outcome.into(),
        payload.source_id,
    );
    result.success(None);
}

impl From<ConsentOutcomePayload> for ConsentOutcome {
    fn from(value: ConsentOutcomePayload) -> Self {
        match value {
            ConsentOutcomePayload::Approved => ConsentOutcome::Approved,
            ConsentOutcomePayload::Cancelled => ConsentOutcome::Cancelled,
        }
    }
}
