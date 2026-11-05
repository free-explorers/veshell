//! `xdg-foreign` exporter and importer support (protocol versions 1 and 2).
//!
//! A portal request names its originating window with an xdg-foreign handle
//! (`wayland:<handle>`). Advertising the exporter lets a client export its
//! toplevel and hand that handle to the portal; tracking the handle here lets
//! the compositor resolve it back to the exported surface — and from there to
//! the MetaWindow — so a dialog can be attached to the exact requester instead
//! of guessing from the app id.
//!
//! The importer is the other half of an out-of-process dialog. Chromium (and
//! therefore Electron) renders its native GTK dialogs — the About box, message
//! boxes — in GTK. GTK cannot call `xdg_toplevel.set_parent` on a surface that
//! belongs to another client, so Electron exports its toplevel and calls
//! `gdk_wayland_window_set_transient_for_exported`. GDK then imports the handle
//! and asks the compositor to `set_parent_of` the dialog surface. Without the
//! importer global GDK cannot express the relation at all, and a modal opened
//! from one of several windows of a single-instance application (two Code OSS
//! windows) has no authoritative owner: it lands on whichever window the
//! matcher guesses. This is why GNOME attaches those dialogs consistently; the
//! importer global is what lets this compositor do the same.

use std::collections::HashMap;
use std::sync::Mutex;

use smithay::reexports::wayland_protocols::xdg::foreign::{
    zv1::server::{
        zxdg_exported_v1::{self, ZxdgExportedV1},
        zxdg_exporter_v1::{self, ZxdgExporterV1},
        zxdg_imported_v1::{self, ZxdgImportedV1},
        zxdg_importer_v1::{self, ZxdgImporterV1},
    },
    zv2::server::{
        zxdg_exported_v2::{self, ZxdgExportedV2},
        zxdg_exporter_v2::{self, ZxdgExporterV2},
        zxdg_imported_v2::{self, ZxdgImportedV2},
        zxdg_importer_v2::{self, ZxdgImporterV2},
    },
};
use smithay::reexports::wayland_server::{
    backend::ClientId, protocol::wl_surface::WlSurface, Client, DataInit, DisplayHandle, New,
};
use smithay::wayland::shell::xdg::XdgPopupSurfaceData;
use smithay::wayland::{Dispatch2, GlobalDispatch2};
use tracing::info;

use crate::backend::Backend;
use crate::meta_window_state::meta_window::MetaWindowPatch;
use crate::state::State;
use crate::wayland::wayland::get_surface_id;

/// User data of the exporter and importer globals. Deliberately not smithay's
/// `GlobalData`: smithay already serves this protocol in
/// `wayland::xdg_foreign`, and a distinct type keeps our dispatch impls from
/// colliding with its.
#[derive(Debug)]
pub struct XdgForeignGlobal;

/// User data of one exported toplevel: the handle the exporting client was
/// given, used to revoke the mapping when the export is destroyed.
#[derive(Debug)]
pub struct XdgForeignExported {
    handle: String,
}

/// User data of one imported toplevel: the exported parent surface it refers
/// to, plus the child surfaces it re-parented so destroying the import can
/// invalidate those relations again.
#[derive(Debug)]
pub struct XdgForeignImported {
    /// The exported parent surface id, or `None` when the handle was already
    /// invalid when the client imported it.
    parent_surface_id: Option<u64>,
    /// Child surface ids passed to `set_parent_of` (deduplicated).
    children: Mutex<Vec<u64>>,
}

/// Exported toplevel handles: each handle string maps to the surface id it was
/// minted for.
#[derive(Debug, Default)]
pub struct XdgForeignState {
    exported: HashMap<String, u64>,
}

impl XdgForeignState {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers the v1 and v2 exporter and importer globals on the display.
    pub fn register<BackendData: Backend + 'static>(display_handle: &DisplayHandle) {
        display_handle.create_global::<State<BackendData>, ZxdgExporterV1, XdgForeignGlobal>(
            1,
            XdgForeignGlobal,
        );
        display_handle.create_global::<State<BackendData>, ZxdgExporterV2, XdgForeignGlobal>(
            1,
            XdgForeignGlobal,
        );
        display_handle.create_global::<State<BackendData>, ZxdgImporterV1, XdgForeignGlobal>(
            1,
            XdgForeignGlobal,
        );
        display_handle.create_global::<State<BackendData>, ZxdgImporterV2, XdgForeignGlobal>(
            1,
            XdgForeignGlobal,
        );
    }

    /// The surface id exported under `handle`, if that export is still live.
    pub fn surface_id(&self, handle: &str) -> Option<u64> {
        self.exported.get(handle).copied()
    }

    fn mint(&mut self, surface_id: u64) -> String {
        // Unguessable, like the portal consent tokens: a handle otherwise
        // lets another client re-import (or the compositor misresolve) an
        // unrelated surface.
        let handle = uuid::Uuid::new_v4().hyphenated().to_string();
        self.exported.insert(handle.clone(), surface_id);
        handle
    }

    fn revoke(&mut self, handle: &str) {
        self.exported.remove(handle);
    }
}

/// Applies an importer's `set_parent_of` request.
///
/// This is the out-of-process equivalent of `xdg_toplevel.set_parent`: the
/// imported surface becomes the child's parent. When the child meta window
/// already exists the relation is patched immediately (the shell re-routes a
/// window whose parent arrives late); otherwise it is remembered by surface id
/// and consumed by [`crate::meta_window_state::MetaWindowState::new_meta_window_for_toplevel`].
fn set_foreign_parent<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    parent_surface_id: Option<u64>,
    child: &WlSurface,
    children: &Mutex<Vec<u64>>,
) {
    let Some(parent_surface_id) = parent_surface_id else {
        return;
    };

    let child_surface_id = get_surface_id(child);
    {
        let mut children = children.lock().unwrap();
        if !children.contains(&child_surface_id) {
            children.push(child_surface_id);
        }
    }

    let parent_meta_window_id = state
        .meta_window_state
        .meta_window_id_per_surface_id
        .get(&parent_surface_id)
        .cloned();
    let child_meta_window_id = state
        .meta_window_state
        .meta_window_id_per_surface_id
        .get(&child_surface_id)
        .cloned();

    match (parent_meta_window_id, child_meta_window_id) {
        (Some(parent_id), Some(child_id)) => {
            info!(
                target: "veshell::geometry",
                meta_window_id = %child_id,
                parent_meta_window_id = %parent_id,
                "xdg-foreign: assigning parent relation"
            );
            state.patch_meta_window(
                MetaWindowPatch::UpdateParent {
                    id: child_id,
                    value: Some(parent_id),
                },
                true,
            );
        }
        (Some(_), None) => {
            info!(
                target: "veshell::geometry",
                child_surface_id,
                parent_surface_id,
                "xdg-foreign: parent relation pending the child toplevel"
            );
            state
                .meta_window_state
                .pending_foreign_parent
                .insert(child_surface_id, parent_surface_id);
        }
        // The child exists but the exported parent has no meta window (yet).
        // The relation cannot be recorded on the child and there is no hook
        // for the parent's creation; the shell falls back to its other signals.
        _ => {}
    }
}

/// Drops the parent relations an imported object established.
///
/// Called when the importer destroys the object or its client disconnects, as
/// required by the protocol: any relationship set up through `set_parent_of`
/// is invalidated at that point.
fn clear_foreign_parents<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    parent_surface_id: Option<u64>,
    children: &Mutex<Vec<u64>>,
) {
    let children = std::mem::take(&mut *children.lock().unwrap());
    if children.is_empty() {
        return;
    }

    let parent_meta_window_id = parent_surface_id.and_then(|surface_id| {
        state
            .meta_window_state
            .meta_window_id_per_surface_id
            .get(&surface_id)
            .cloned()
    });

    for child_surface_id in children {
        let Some(child_id) = state
            .meta_window_state
            .meta_window_id_per_surface_id
            .get(&child_surface_id)
            .cloned()
        else {
            state
                .meta_window_state
                .pending_foreign_parent
                .remove(&child_surface_id);
            continue;
        };
        let still_parented_by_this_import =
            parent_meta_window_id.as_deref().is_some_and(|parent_id| {
                state
                    .meta_window_state
                    .meta_windows
                    .get(&child_id)
                    .is_some_and(|meta_window| meta_window.parent.as_deref() == Some(parent_id))
            });
        // The exported parent may already be gone (its meta window was
        // destroyed with the handle). The relation this import established is
        // invalid either way, so clear a parent id that no longer resolves.
        let parent_is_gone = state
            .meta_window_state
            .meta_windows
            .get(&child_id)
            .and_then(|meta_window| meta_window.parent.as_deref())
            .is_some_and(|parent_id| !state.meta_window_state.meta_windows.contains_key(parent_id));
        if still_parented_by_this_import || parent_is_gone {
            state.patch_meta_window(
                MetaWindowPatch::UpdateParent {
                    id: child_id,
                    value: None,
                },
                true,
            );
        }
    }
}

/// Whether `surface` may become an `xdg_toplevel`.
///
/// `set_parent_of` is only valid for toplevels, but GTK can apply the transient
/// relation before the dialog's role is created. A surface with no role yet is
/// therefore accepted (the pending parent is consumed when its toplevel is
/// created); a popup is rejected because it can never become a toplevel.
fn is_or_will_be_toplevel(surface: &WlSurface) -> bool {
    smithay::wayland::compositor::with_states(surface, |surface_data| {
        surface_data.data_map.get::<XdgPopupSurfaceData>().is_none()
    })
}

//
// v1
//

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgExporterV1, State<BackendData>>
    for XdgForeignGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgExporterV1>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExporterV1, State<BackendData>>
    for XdgForeignGlobal
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgExporterV1,
        request: zxdg_exporter_v1::Request,
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_exporter_v1::Request::Export { id, surface } => {
                let handle = state.xdg_foreign_state.mint(get_surface_id(&surface));
                let exported = data_init.init(
                    id,
                    XdgForeignExported {
                        handle: handle.clone(),
                    },
                );
                exported.handle(handle);
            }
            zxdg_exporter_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExportedV1, State<BackendData>>
    for XdgForeignExported
{
    fn request(
        &self,
        _state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgExportedV1,
        request: zxdg_exported_v1::Request,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_exported_v1::Request::Destroy => {}
            _ => {}
        }
    }

    fn destroyed(
        &self,
        state: &mut State<BackendData>,
        _client: ClientId,
        _resource: &ZxdgExportedV1,
    ) {
        state.xdg_foreign_state.revoke(&self.handle);
    }
}

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgImporterV1, State<BackendData>>
    for XdgForeignGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgImporterV1>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgImporterV1, State<BackendData>>
    for XdgForeignGlobal
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgImporterV1,
        request: zxdg_importer_v1::Request,
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_importer_v1::Request::Import { id, handle } => {
                let parent_surface_id = state.xdg_foreign_state.surface_id(&handle);
                let imported = data_init.init(
                    id,
                    XdgForeignImported {
                        parent_surface_id,
                        children: Mutex::new(Vec::new()),
                    },
                );
                if parent_surface_id.is_none() {
                    // An invalid handle still yields an object; the protocol
                    // says it becomes inert immediately.
                    imported.destroyed();
                }
            }
            zxdg_importer_v1::Request::Destroy => {}
            _ => {}
        }
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgImportedV1, State<BackendData>>
    for XdgForeignImported
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgImportedV1,
        request: zxdg_imported_v1::Request,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_imported_v1::Request::SetParentOf { surface } => {
                if is_or_will_be_toplevel(&surface) {
                    set_foreign_parent(state, self.parent_surface_id, &surface, &self.children);
                }
            }
            zxdg_imported_v1::Request::Destroy => {}
            _ => {}
        }
    }

    fn destroyed(
        &self,
        state: &mut State<BackendData>,
        _client: ClientId,
        _resource: &ZxdgImportedV1,
    ) {
        clear_foreign_parents(state, self.parent_surface_id, &self.children);
    }
}

//
// v2
//

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgExporterV2, State<BackendData>>
    for XdgForeignGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgExporterV2>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExporterV2, State<BackendData>>
    for XdgForeignGlobal
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgExporterV2,
        request: zxdg_exporter_v2::Request,
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_exporter_v2::Request::ExportToplevel { id, surface } => {
                let handle = state.xdg_foreign_state.mint(get_surface_id(&surface));
                let exported = data_init.init(
                    id,
                    XdgForeignExported {
                        handle: handle.clone(),
                    },
                );
                exported.handle(handle);
            }
            zxdg_exporter_v2::Request::Destroy => {}
            _ => {}
        }
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExportedV2, State<BackendData>>
    for XdgForeignExported
{
    fn request(
        &self,
        _state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgExportedV2,
        request: zxdg_exported_v2::Request,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_exported_v2::Request::Destroy => {}
            _ => {}
        }
    }

    fn destroyed(
        &self,
        state: &mut State<BackendData>,
        _client: ClientId,
        _resource: &ZxdgExportedV2,
    ) {
        state.xdg_foreign_state.revoke(&self.handle);
    }
}

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgImporterV2, State<BackendData>>
    for XdgForeignGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgImporterV2>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgImporterV2, State<BackendData>>
    for XdgForeignGlobal
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgImporterV2,
        request: zxdg_importer_v2::Request,
        _dhandle: &DisplayHandle,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_importer_v2::Request::ImportToplevel { id, handle } => {
                let parent_surface_id = state.xdg_foreign_state.surface_id(&handle);
                let imported = data_init.init(
                    id,
                    XdgForeignImported {
                        parent_surface_id,
                        children: Mutex::new(Vec::new()),
                    },
                );
                if parent_surface_id.is_none() {
                    imported.destroyed();
                }
            }
            zxdg_importer_v2::Request::Destroy => {}
            _ => {}
        }
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgImportedV2, State<BackendData>>
    for XdgForeignImported
{
    fn request(
        &self,
        state: &mut State<BackendData>,
        _client: &Client,
        _resource: &ZxdgImportedV2,
        request: zxdg_imported_v2::Request,
        _dhandle: &DisplayHandle,
        _data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        match request {
            zxdg_imported_v2::Request::SetParentOf { surface } => {
                if is_or_will_be_toplevel(&surface) {
                    set_foreign_parent(state, self.parent_surface_id, &surface, &self.children);
                }
            }
            zxdg_imported_v2::Request::Destroy => {}
            _ => {}
        }
    }

    fn destroyed(
        &self,
        state: &mut State<BackendData>,
        _client: ClientId,
        _resource: &ZxdgImportedV2,
    ) {
        clear_foreign_parents(state, self.parent_surface_id, &self.children);
    }
}
