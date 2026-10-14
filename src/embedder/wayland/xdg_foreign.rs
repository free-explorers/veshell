//! `xdg-foreign` exporter support (protocol versions 1 and 2).
//!
//! A portal request names its originating window with an xdg-foreign handle
//! (`wayland:<handle>`). Advertising the exporter lets a client export its
//! toplevel and hand that handle to the portal; tracking the handle here lets
//! the compositor resolve it back to the exported surface — and from there to
//! the MetaWindow — so a dialog can be attached to the exact requester instead
//! of guessing from the app id.
//!
//! Only the exporter is implemented. The importer (`zxdg_importer`) lets a
//! client re-parent another client's surface to its own; no shell behaviour
//! depends on that, and portal window identification does not need it.

use std::collections::HashMap;

use smithay::reexports::wayland_protocols::xdg::foreign::{
    zv1::server::{
        zxdg_exported_v1::{self, ZxdgExportedV1},
        zxdg_exporter_v1::{self, ZxdgExporterV1},
    },
    zv2::server::{
        zxdg_exported_v2::{self, ZxdgExportedV2},
        zxdg_exporter_v2::{self, ZxdgExporterV2},
    },
};
use smithay::reexports::wayland_server::{backend::ClientId, Client, DataInit, DisplayHandle, New};
use smithay::wayland::{Dispatch2, GlobalDispatch2};

use crate::backend::Backend;
use crate::state::State;
use crate::wayland::wayland::get_surface_id;

/// User data of the exporter globals. Deliberately not smithay's `GlobalData`:
/// smithay already serves this protocol in `wayland::xdg_foreign`, and a
/// distinct type keeps our dispatch impls from colliding with its.
#[derive(Debug)]
pub struct XdgForeignExporterGlobal;

/// User data of one exported toplevel: the handle the exporting client was
/// given, used to revoke the mapping when the export is destroyed.
#[derive(Debug)]
pub struct XdgForeignExported {
    handle: String,
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

    /// Registers the v1 and v2 exporter globals on the display.
    pub fn register<BackendData: Backend + 'static>(display_handle: &DisplayHandle) {
        display_handle
            .create_global::<State<BackendData>, ZxdgExporterV1, XdgForeignExporterGlobal>(
                1,
                XdgForeignExporterGlobal,
            );
        display_handle
            .create_global::<State<BackendData>, ZxdgExporterV2, XdgForeignExporterGlobal>(
                1,
                XdgForeignExporterGlobal,
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

//
// v1
//

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgExporterV1, State<BackendData>>
    for XdgForeignExporterGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgExporterV1>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignExporterGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExporterV1, State<BackendData>>
    for XdgForeignExporterGlobal
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

//
// v2
//

impl<BackendData: Backend + 'static> GlobalDispatch2<ZxdgExporterV2, State<BackendData>>
    for XdgForeignExporterGlobal
{
    fn bind(
        &self,
        _state: &mut State<BackendData>,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ZxdgExporterV2>,
        data_init: &mut DataInit<'_, State<BackendData>>,
    ) {
        data_init.init(resource, XdgForeignExporterGlobal);
    }
}

impl<BackendData: Backend + 'static> Dispatch2<ZxdgExporterV2, State<BackendData>>
    for XdgForeignExporterGlobal
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
