use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ReleaseTexturePayload {
    pub(crate) texture_id: i64,
}

/// The shell is done with the last frame of a window it closed (see
/// `State::release_surface_textures`). Only a texture kept after its surface
/// was destroyed is released; any other id is ignored.
pub fn release_texture<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let payload = method_call
        .arguments()
        .cloned()
        .and_then(|args| serde_json::from_value::<ReleaseTexturePayload>(args).ok());
    let Some(payload) = payload else {
        result.error(
            "invalid_arguments".to_string(),
            "release_texture expects a textureId".to_string(),
            None,
        );
        return;
    };
    data.release_retained_texture(payload.texture_id);
    result.success(None);
}
