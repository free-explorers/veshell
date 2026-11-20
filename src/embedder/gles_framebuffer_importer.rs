//! Converts dmabufs into OpenGL framebuffer objects and caches them.
//! Destroys the framebuffers when their source dmabuf fd is closed.
//!
//! Code was copied from GlesRenderer from Smithay because unfortunately buffer importing
//! and rendering are merged together, and I only wanted the buffer importing part. Smithay's code
//! also creates an unnecessary shadow buffer that I don't need.
//!
//! I don't care about the rendering part because Flutter will handle everything.
//! Smithay is not modular enough to accommodate third-party renderers very well, so this is the
//! only option for now until I, or someone else, refactors the renderers into 2 parts: buffer
//! importing and rendering.
//!
//! # View targets
//!
//! Flutter does not render into the backing stores themselves but into a
//! target of each view ([`ViewTarget`]), whose frame is then copied into the
//! backing store when it is presented ([`GlesFramebufferImporter::present`]).
//!
//! * Multisampling. Impeller antialiases paths and clips through
//!   multisampling, but only multisamples a framebuffer the embedder hands it
//!   when the driver resolves implicitly
//!   (`GL_EXT_multisampled_render_to_texture`), which desktop Mesa does not.
//!   The view's render target is multisampled instead, and resolved on
//!   present, as Flutter's own GTK embedder does. The sample count follows
//!   the `theme.antialiasing` setting ([`set_antialiasing`]); `auto` weighs the
//!   GPU (see [`GpuKind`]).
//! * Partial repaint. The view's target also keeps its last complete frame,
//!   so the engine paints only what changed
//!   ([`GlesFramebufferImporter::keeps_last_frame`]) and only that is
//!   resolved into it; the backing store then receives what changed since
//!   it last held the frame, and the compositor repaints only that part of
//!   the output.
//!
//! Drivers without GLES 3 framebuffer blits cannot copy a frame: Flutter then
//! renders into the backing store directly, whole and single-sample.

use core::ffi::{c_char, CStr};

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::{Arc, Mutex};

use smithay::backend::allocator::Buffer;
use smithay::backend::egl::{EGLDevice, EGLDisplay};
use smithay::backend::renderer::Texture;
use smithay::backend::{
    allocator::dmabuf::{Dmabuf, WeakDmabuf},
    egl::{
        self,
        ffi::egl::{self as ffi_egl, types::EGLImage},
        EGLContext, MakeCurrentError,
    },
    renderer::gles::{ffi, GlesError, GlesTexture},
};
use smithay::utils::{Buffer as BufferCoords, Rectangle};
use tracing::{info, trace};

use crate::settings::Antialiasing;

/// The `theme.antialiasing` setting, written by the settings on the main
/// thread and read by the importer on the raster thread.
static ANTIALIASING: AtomicU8 = AtomicU8::new(0);

/// Records the `theme.antialiasing` setting; the next frame renders with it.
/// Returns whether it changed.
pub fn set_antialiasing(antialiasing: Antialiasing) -> bool {
    let value = match antialiasing {
        Antialiasing::Auto => 0,
        Antialiasing::Off => 1,
        Antialiasing::X2 => 2,
        Antialiasing::X4 => 3,
    };
    ANTIALIASING.swap(value, Ordering::Relaxed) != value
}

fn antialiasing() -> Antialiasing {
    match ANTIALIASING.load(Ordering::Relaxed) {
        1 => Antialiasing::Off,
        2 => Antialiasing::X2,
        3 => Antialiasing::X4,
        _ => Antialiasing::Auto,
    }
}

/// What kind of GPU Flutter renders on, as far as `auto` antialiasing cares.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum GpuKind {
    /// Its own memory: multisampling costs little of what the rest of the
    /// system needs.
    Dedicated,
    /// Memory and bandwidth shared with the CPU; also the guess when unsure.
    Integrated,
    /// A software rasterizer (llvmpipe, softpipe, swrast): every sample is
    /// CPU time.
    Software,
}

/// The GPU's kind, whether it blits between framebuffers (GLES 3), and how
/// many samples its multisampled renderbuffers take (0 without GLES 3).
#[derive(Debug, Clone, Copy)]
struct Gpu {
    kind: GpuKind,
    blits: bool,
    max_samples: i32,
}

impl Gpu {
    /// The sample count to render with under `antialiasing`; 1 renders
    /// straight into the backing store.
    fn samples(self, antialiasing: Antialiasing) -> i32 {
        let wanted = match antialiasing {
            Antialiasing::Off => 1,
            Antialiasing::X2 => 2,
            Antialiasing::X4 => 4,
            Antialiasing::Auto => match self.kind {
                GpuKind::Dedicated => 4,
                GpuKind::Integrated => 2,
                GpuKind::Software => 1,
            },
        };
        [4, 2]
            .into_iter()
            .find(|&samples| samples <= wanted && samples <= self.max_samples)
            .unwrap_or(1)
    }
}

pub struct GlesFramebufferImporter {
    gl: ffi::Gles2,
    egl_display: EGLDisplay,
    /// The GPU Flutter renders on; known once a context is current.
    gpu: Option<Gpu>,

    // caches
    buffers: Vec<GlesFramebuffer>,
    /// The depth/stencil renderbuffer of each framebuffer made by
    /// [`Self::import_texture`] for direct rendering (0 otherwise), released
    /// with it.
    texture_framebuffers: HashMap<ffi::types::GLuint, ffi::types::GLuint>,
    view_targets: Vec<ViewTarget>,
    /// Views removed since the last frame, whose targets are to be released.
    removed_views: Arc<Mutex<Vec<i64>>>,
}

/// Releases the target of a removed view.
///
/// A view's target is a set of GL objects of Flutter's context, released on
/// the raster thread; views are removed on the main thread. The release waits
/// for the next frame rendered. A view that only renders now and then keeps
/// its target meanwhile: its next frame is still painted in part.
#[derive(Debug, Clone)]
pub struct ViewTargetReleaser(Arc<Mutex<Vec<i64>>>);

impl ViewTargetReleaser {
    pub fn release(&self, view_id: i64) {
        self.0.lock().unwrap().push(view_id);
    }
}

#[derive(Debug, Clone)]
struct GlesFramebuffer {
    dmabuf: WeakDmabuf,
    image: EGLImage,
    rbo: ffi::types::GLuint,
    /// Only when Flutter renders into it directly (no blits); 0 otherwise.
    depth_stencil: ffi::types::GLuint,
    fbo: ffi::types::GLuint,
}

/// What Flutter renders a view into, and the view's last complete frame.
#[derive(Debug)]
struct ViewTarget {
    view_id: i64,
    width: i32,
    height: i32,
    samples: i32,
    /// Flutter's render target: color and depth/stencil of `samples` samples.
    /// What it holds outside the painted region is undefined.
    render_fbo: ffi::types::GLuint,
    render_color: ffi::types::GLuint,
    render_depth_stencil: ffi::types::GLuint,
    /// The view's last complete frame, single-sample.
    frame_fbo: ffi::types::GLuint,
    frame_color: ffi::types::GLuint,
    /// Whether `frame` holds the view's last frame (not yet, once created).
    frame_valid: bool,
    /// For each backing store `frame` was copied into, what changed in
    /// `frame` since (`None`: nothing). A backing store not listed is copied
    /// whole.
    behind: HashMap<ffi::types::GLuint, Option<GlRect>>,
}

/// A rectangle of a framebuffer in GL's coordinates: `(x0, y0, x1, y1)`, rows
/// from the bottom.
type GlRect = (i32, i32, i32, i32);

/// What `backing_store` must receive of a frame that changed `changed`, and
/// what the other backing stores now lag by.
///
/// The engine cycles through a few backing stores: each one lags the frame by
/// what changed since it last received it, and one never seen lags by all of
/// it (`full`).
fn catch_up(
    behind: &mut HashMap<ffi::types::GLuint, Option<GlRect>>,
    backing_store: ffi::types::GLuint,
    changed: GlRect,
    full: GlRect,
) -> Option<GlRect> {
    let copied = match behind.get(&backing_store) {
        Some(&pending) => union(pending, changed),
        None => Some(full),
    };
    for (fbo, pending) in behind.iter_mut() {
        if *fbo != backing_store {
            *pending = union(*pending, changed);
        }
    }
    behind.insert(backing_store, None);
    copied
}

/// The bounding box of `pending` and `rect`.
fn union(pending: Option<GlRect>, rect: GlRect) -> Option<GlRect> {
    let (x0, y0, x1, y1) = rect;
    if x0 >= x1 || y0 >= y1 {
        return pending;
    }
    Some(match pending {
        None => rect,
        Some((a0, b0, a1, b1)) => (a0.min(x0), b0.min(y0), a1.max(x1), b1.max(y1)),
    })
}

/// The framebuffer Flutter renders a backing store into.
#[derive(Debug, Clone, Copy)]
pub struct ImportedTarget {
    /// The framebuffer handed to Flutter.
    pub render_fbo: ffi::types::GLuint,
    /// What moves the frame into the backing store once it is submitted;
    /// `None` when Flutter renders into the backing store directly.
    pub present: Option<Present>,
}

/// The copy of a view's frame into a backing store, run once Flutter has
/// submitted the frame.
#[derive(Debug, Clone, Copy)]
pub struct Present {
    view_id: i64,
    backing_store_fbo: ffi::types::GLuint,
    width: i32,
    height: i32,
}

/// A rectangle of a frame, in Flutter's coordinates: physical pixels from the
/// top-left corner.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PaintedRegion {
    pub left: f64,
    pub top: f64,
    pub right: f64,
    pub bottom: f64,
}

impl GlesFramebufferImporter {
    pub unsafe fn new(egl_display: EGLDisplay) -> Result<Self, GlesError> {
        let gl = ffi::Gles2::load_with(|s| egl::get_proc_address(s) as *const _);

        info!("Initializing OpenGL ES buffer importer");
        info!(
            "GL Version: {:?}",
            CStr::from_ptr(gl.GetString(ffi::VERSION) as *const c_char),
        );
        info!(
            "GL Vendor: {:?}",
            CStr::from_ptr(gl.GetString(ffi::VENDOR) as *const c_char),
        );
        info!(
            "GL Renderer: {:?}",
            CStr::from_ptr(gl.GetString(ffi::RENDERER) as *const c_char),
        );

        Ok(Self {
            gl,
            egl_display,
            gpu: None,
            buffers: vec![],
            texture_framebuffers: HashMap::new(),
            view_targets: vec![],
            removed_views: Arc::default(),
        })
    }

    /// Imports a plain GL texture as a framebuffer Flutter can render into.
    ///
    /// This is the fallback used when the backend has no DRM render node and
    /// therefore cannot allocate dmabufs. Smithay's `GlesRenderer` can render
    /// into a texture, but it owns the framebuffer object privately; Flutter's
    /// compositor instead needs the raw FBO name, so it is created here.
    ///
    /// A fresh framebuffer is created per backing store: Flutter may recycle a
    /// texture while an older frame is still being collected, so caching by
    /// texture name could delete the framebuffer of a live frame.
    ///
    /// Returns the backing store's own framebuffer, which
    /// [`Self::release_texture_framebuffer`] takes, and what Flutter renders
    /// into.
    pub fn import_texture(
        &mut self,
        egl_context: &EGLContext,
        view_id: i64,
        texture: &GlesTexture,
    ) -> Result<(ffi::types::GLuint, ImportedTarget), GlesError> {
        self.make_current(egl_context)?;
        let direct = !self.gpu().blits;

        unsafe {
            let mut fbo = 0;
            self.gl.GenFramebuffers(1, &mut fbo as *mut _);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, fbo);
            self.gl.FramebufferTexture2D(
                ffi::FRAMEBUFFER,
                ffi::COLOR_ATTACHMENT0,
                ffi::TEXTURE_2D,
                texture.tex_id(),
                0,
            );
            let size = texture.size();
            let depth_stencil = if direct {
                self.attach_depth_stencil(size.w, size.h, 1)
            } else {
                0
            };
            let status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

            if status != ffi::FRAMEBUFFER_COMPLETE {
                self.gl.DeleteFramebuffers(1, &fbo as *const _);
                self.gl.DeleteRenderbuffers(1, &depth_stencil as *const _);
                return Err(GlesError::FramebufferBindingError);
            }
            self.texture_framebuffers.insert(fbo, depth_stencil);

            trace!(
                texture_id = texture.tex_id(),
                fbo,
                "Created framebuffer for Flutter texture"
            );
            match self.render_target(view_id, fbo, size.w, size.h) {
                Ok(target) => Ok((fbo, target)),
                Err(error) => {
                    self.forget_texture_framebuffer(fbo);
                    Err(error)
                }
            }
        }
    }

    /// Releases a framebuffer created by [`Self::import_texture`].
    pub fn release_texture_framebuffer(
        &mut self,
        egl_context: &EGLContext,
        fbo: ffi::types::GLuint,
    ) -> Result<(), MakeCurrentError> {
        self.make_current(egl_context)?;
        self.forget_texture_framebuffer(fbo);
        Ok(())
    }

    fn forget_texture_framebuffer(&mut self, fbo: ffi::types::GLuint) {
        self.forget_backing_store(fbo);
        unsafe {
            self.gl.DeleteFramebuffers(1, &fbo as *const _);
            if let Some(depth_stencil) = self.texture_framebuffers.remove(&fbo) {
                self.gl.DeleteRenderbuffers(1, &depth_stencil as *const _);
            }
        }
    }

    pub fn import_framebuffer(
        &mut self,
        egl_context: &EGLContext,
        view_id: i64,
        dmabuf: Dmabuf,
    ) -> Result<ImportedTarget, GlesError> {
        self.make_current(egl_context)?;
        let direct = !self.gpu().blits;

        let fbo = self
            .buffers
            .iter_mut()
            .find(|buffer| {
                if let Some(dma) = buffer.dmabuf.upgrade() {
                    dma == dmabuf
                } else {
                    false
                }
            })
            .map(|buf| Ok::<_, GlesError>(buf.fbo))
            .unwrap_or_else(|| {
                trace!("Creating EGLImage for Dmabuf: {:?}", dmabuf);
                let image = egl_context
                    .display()
                    .create_image_from_dmabuf(&dmabuf)
                    .map_err(GlesError::BindBufferEGLError)?;

                unsafe {
                    let mut rbo = 0;
                    self.gl.GenRenderbuffers(1, &mut rbo as *mut _);
                    self.gl.BindRenderbuffer(ffi::RENDERBUFFER, rbo);
                    self.gl
                        .EGLImageTargetRenderbufferStorageOES(ffi::RENDERBUFFER, image);
                    self.gl.BindRenderbuffer(ffi::RENDERBUFFER, 0);

                    let mut fbo = 0;
                    self.gl.GenFramebuffers(1, &mut fbo as *mut _);
                    self.gl.BindFramebuffer(ffi::FRAMEBUFFER, fbo);
                    self.gl.FramebufferRenderbuffer(
                        ffi::FRAMEBUFFER,
                        ffi::COLOR_ATTACHMENT0,
                        ffi::RENDERBUFFER,
                        rbo,
                    );
                    let depth_stencil = if direct {
                        self.attach_depth_stencil(dmabuf.width() as i32, dmabuf.height() as i32, 1)
                    } else {
                        0
                    };
                    let status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
                    self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

                    if status != ffi::FRAMEBUFFER_COMPLETE {
                        //TODO wrap image and drop here
                        self.gl.DeleteRenderbuffers(1, &depth_stencil as *const _);
                        return Err(GlesError::FramebufferBindingError);
                    }

                    let buf = GlesFramebuffer {
                        dmabuf: dmabuf.weak(),
                        image,
                        rbo,
                        depth_stencil,
                        fbo,
                    };

                    self.buffers.push(buf);

                    Ok(fbo)
                }
            })?;

        let target =
            self.render_target(view_id, fbo, dmabuf.width() as i32, dmabuf.height() as i32)?;
        self.make_current(egl_context)?;
        Ok(target)
    }

    /// Whether the view's target still holds its last complete frame for the
    /// frame about to be rendered, which then only needs what changed.
    ///
    /// Called on the raster thread before Flutter renders a frame of the
    /// view. A view without a target, one whose target is about to be
    /// remade with another sample count (the setting changed), or one whose
    /// last frame was never completed repaints whole. A view about to change
    /// size is repainted whole by the engine itself.
    pub fn keeps_last_frame(&mut self, view_id: i64) -> bool {
        let Some(gpu) = self.gpu else {
            return false;
        };
        let samples = gpu.samples(antialiasing());
        self.view_targets
            .iter()
            .find(|target| target.view_id == view_id)
            .is_some_and(|target| target.frame_valid && target.samples == samples)
    }

    /// What lets the main thread release a removed view's target.
    pub fn view_target_releaser(&self) -> ViewTargetReleaser {
        ViewTargetReleaser(self.removed_views.clone())
    }

    /// Moves a submitted frame into its backing store.
    ///
    /// Resolves what Flutter painted (`painted`, `None` for all of it) from the
    /// view's render target into its last frame, then brings the backing store
    /// up to that frame: whatever changed since it last received one, or all
    /// of it the first time.
    ///
    /// Called on the raster thread once Flutter has submitted the frame, with
    /// its context current and before the fence that tells the compositor the
    /// frame is ready. The GL state the blits depend on is restored after
    /// them: Impeller tracks some of its own.
    ///
    /// Returns what differs from the view's previous frame, in the texture's
    /// own coordinates (rows from the bottom, as GL stores Flutter's frames),
    /// or `None` when the whole frame may have changed.
    pub fn present(
        &mut self,
        present: Present,
        painted: Option<PaintedRegion>,
    ) -> Option<Rectangle<i32, BufferCoords>> {
        let target = self
            .view_targets
            .iter_mut()
            .find(|target| target.view_id == present.view_id)?;
        let (width, height) = (target.width, target.height);
        if (width, height) != (present.width, present.height) {
            return None;
        }
        // Flutter's coordinates run down from the top; GL's up from the
        // bottom, where Flutter's frames are drawn upside up.
        let full = (0, 0, width, height);
        let resolved = match painted {
            Some(region) if target.frame_valid => {
                let left = (region.left.floor() as i32).clamp(0, width);
                let right = (region.right.ceil() as i32).clamp(0, width);
                let top = (region.top.floor() as i32).clamp(0, height);
                let bottom = (region.bottom.ceil() as i32).clamp(0, height);
                (left, height - bottom, right, height - top)
            }
            _ => full,
        };
        let changed = (resolved != full).then(|| {
            let (x0, y0, x1, y1) = resolved;
            Rectangle::new((x0, y0).into(), ((x1 - x0).max(0), (y1 - y0).max(0)).into())
        });
        trace!(
            view = present.view_id,
            ?painted,
            ?resolved,
            "Presenting a frame"
        );
        let (render_fbo, frame_fbo) = (target.render_fbo, target.frame_fbo);
        target.frame_valid = true;
        let backing_store = present.backing_store_fbo;
        let copied = catch_up(&mut target.behind, backing_store, resolved, full);

        unsafe {
            let mut read_binding = 0;
            let mut draw_binding = 0;
            self.gl
                .GetIntegerv(ffi::READ_FRAMEBUFFER_BINDING, &mut read_binding);
            self.gl
                .GetIntegerv(ffi::DRAW_FRAMEBUFFER_BINDING, &mut draw_binding);
            // The scissor test is the one fragment operation a blit obeys.
            let scissor = self.gl.IsEnabled(ffi::SCISSOR_TEST) == ffi::TRUE;
            if scissor {
                self.gl.Disable(ffi::SCISSOR_TEST);
            }

            let (x0, y0, x1, y1) = resolved;
            if x0 < x1 && y0 < y1 {
                // A multisample resolve needs the same rectangle on both sides.
                self.blit(render_fbo, frame_fbo, resolved, resolved);
            }
            // Nothing reads the render target again: the next frame clears it.
            let attachments = [ffi::COLOR_ATTACHMENT0, ffi::DEPTH_STENCIL_ATTACHMENT];
            self.gl.InvalidateFramebuffer(
                ffi::READ_FRAMEBUFFER,
                attachments.len() as i32,
                attachments.as_ptr(),
            );
            if let Some(copied) = copied {
                self.blit(frame_fbo, backing_store, copied, copied);
            }

            self.gl
                .BindFramebuffer(ffi::READ_FRAMEBUFFER, read_binding as ffi::types::GLuint);
            self.gl
                .BindFramebuffer(ffi::DRAW_FRAMEBUFFER, draw_binding as ffi::types::GLuint);
            if scissor {
                self.gl.Enable(ffi::SCISSOR_TEST);
            }
        }
        changed
    }

    /// Blits the color of `from`'s rectangle into `to`'s, leaving `from`
    /// bound for reading.
    unsafe fn blit(
        &self,
        from: ffi::types::GLuint,
        to: ffi::types::GLuint,
        (sx0, sy0, sx1, sy1): (i32, i32, i32, i32),
        (dx0, dy0, dx1, dy1): (i32, i32, i32, i32),
    ) {
        self.gl.BindFramebuffer(ffi::READ_FRAMEBUFFER, from);
        self.gl.BindFramebuffer(ffi::DRAW_FRAMEBUFFER, to);
        self.gl.BlitFramebuffer(
            sx0,
            sy0,
            sx1,
            sy1,
            dx0,
            dy0,
            dx1,
            dy1,
            ffi::COLOR_BUFFER_BIT,
            ffi::NEAREST,
        );
    }

    /// The framebuffer Flutter renders a frame of `view_id`, presented in the
    /// backing store whose framebuffer is `fbo`, into.
    fn render_target(
        &mut self,
        view_id: i64,
        fbo: ffi::types::GLuint,
        width: i32,
        height: i32,
    ) -> Result<ImportedTarget, GlesError> {
        let gpu = self.gpu();
        if !gpu.blits {
            return Ok(ImportedTarget {
                render_fbo: fbo,
                present: None,
            });
        }
        let render_fbo = self.view_target(view_id, width, height, gpu.samples(antialiasing()))?;
        Ok(ImportedTarget {
            render_fbo,
            present: Some(Present {
                view_id,
                backing_store_fbo: fbo,
                width,
                height,
            }),
        })
    }

    /// The render framebuffer of `view_id`'s target, made (or remade, at
    /// another size or sample count) on demand; targets of removed views are
    /// released.
    fn view_target(
        &mut self,
        view_id: i64,
        width: i32,
        height: i32,
        samples: i32,
    ) -> Result<ffi::types::GLuint, GlesError> {
        let removed = std::mem::take(&mut *self.removed_views.lock().unwrap());
        let mut i = 0;
        while i != self.view_targets.len() {
            let target = &self.view_targets[i];
            let stale = if target.view_id == view_id {
                (target.width, target.height, target.samples) != (width, height, samples)
            } else {
                removed.contains(&target.view_id)
            };
            if stale {
                let target = self.view_targets.remove(i);
                self.drop_view_target(&target);
            } else {
                i += 1;
            }
        }
        if let Some(target) = self
            .view_targets
            .iter_mut()
            .find(|target| target.view_id == view_id)
        {
            return Ok(target.render_fbo);
        }

        unsafe {
            let mut target = ViewTarget {
                view_id,
                width,
                height,
                samples,
                render_fbo: 0,
                render_color: 0,
                render_depth_stencil: 0,
                frame_fbo: 0,
                frame_color: 0,
                frame_valid: false,
                behind: HashMap::new(),
            };
            target.render_color = self.renderbuffer(ffi::RGBA8, width, height, samples);
            self.gl.GenFramebuffers(1, &mut target.render_fbo as *mut _);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, target.render_fbo);
            self.gl.FramebufferRenderbuffer(
                ffi::FRAMEBUFFER,
                ffi::COLOR_ATTACHMENT0,
                ffi::RENDERBUFFER,
                target.render_color,
            );
            target.render_depth_stencil = self.attach_depth_stencil(width, height, samples);
            let render_status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);

            target.frame_color = self.renderbuffer(ffi::RGBA8, width, height, 1);
            self.gl.GenFramebuffers(1, &mut target.frame_fbo as *mut _);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, target.frame_fbo);
            self.gl.FramebufferRenderbuffer(
                ffi::FRAMEBUFFER,
                ffi::COLOR_ATTACHMENT0,
                ffi::RENDERBUFFER,
                target.frame_color,
            );
            let frame_status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

            if render_status != ffi::FRAMEBUFFER_COMPLETE
                || frame_status != ffi::FRAMEBUFFER_COMPLETE
            {
                self.drop_view_target(&target);
                return Err(GlesError::FramebufferBindingError);
            }
            info!(view_id, width, height, samples, "Created a view target");
            let render_fbo = target.render_fbo;
            self.view_targets.push(target);
            Ok(render_fbo)
        }
    }

    unsafe fn renderbuffer(
        &self,
        format: ffi::types::GLenum,
        width: i32,
        height: i32,
        samples: i32,
    ) -> ffi::types::GLuint {
        let mut renderbuffer = 0;
        self.gl.GenRenderbuffers(1, &mut renderbuffer as *mut _);
        self.gl.BindRenderbuffer(ffi::RENDERBUFFER, renderbuffer);
        if samples > 1 {
            self.gl.RenderbufferStorageMultisample(
                ffi::RENDERBUFFER,
                samples,
                format,
                width,
                height,
            );
        } else {
            self.gl
                .RenderbufferStorage(ffi::RENDERBUFFER, format, width, height);
        }
        self.gl.BindRenderbuffer(ffi::RENDERBUFFER, 0);
        renderbuffer
    }

    fn drop_view_target(&self, target: &ViewTarget) {
        unsafe {
            for fbo in [target.render_fbo, target.frame_fbo] {
                self.gl.DeleteFramebuffers(1, &fbo as *const _);
            }
            for renderbuffer in [
                target.render_color,
                target.render_depth_stencil,
                target.frame_color,
            ] {
                self.gl.DeleteRenderbuffers(1, &renderbuffer as *const _);
            }
        }
    }

    /// The GPU Flutter renders on. Needs a current context.
    fn gpu(&mut self) -> Gpu {
        if let Some(gpu) = self.gpu {
            return gpu;
        }
        let (renderer, major, max_samples) = unsafe {
            let renderer = CStr::from_ptr(self.gl.GetString(ffi::RENDERER) as *const c_char)
                .to_string_lossy()
                .to_ascii_lowercase();
            let mut major = 0;
            self.gl.GetIntegerv(ffi::MAJOR_VERSION, &mut major);
            let mut max_samples = 0;
            if major >= 3 {
                self.gl.GetIntegerv(ffi::MAX_SAMPLES, &mut max_samples);
            }
            (renderer, major, max_samples)
        };
        let kind = if ["llvmpipe", "softpipe", "swrast"]
            .iter()
            .any(|name| renderer.contains(name))
        {
            GpuKind::Software
        } else {
            EGLDevice::device_for_display(&self.egl_display)
                .and_then(|device| device.drm_device_path())
                .ok()
                .and_then(|path| path.file_name().map(|name| name.to_owned()))
                .map(|name| sysfs_gpu_kind(&Path::new("/sys/class/drm").join(name).join("device")))
                .unwrap_or(GpuKind::Integrated)
        };
        let gpu = Gpu {
            kind,
            blits: major >= 3,
            max_samples,
        };
        info!(
            ?kind,
            max_samples, renderer, "Flutter's GPU, for antialiasing"
        );
        self.gpu = Some(gpu);
        gpu
    }

    /// Attaches a depth/stencil renderbuffer of `width`x`height` with
    /// `samples` samples to the bound framebuffer and returns it.
    ///
    /// Impeller fills paths and clips through the stencil buffer, and a
    /// framebuffer the embedder hands it must come with its own: Impeller only
    /// describes the attachment (a placeholder) and draws with what is bound.
    /// Without one, every path fill covers its whole bounds.
    unsafe fn attach_depth_stencil(
        &self,
        width: i32,
        height: i32,
        samples: i32,
    ) -> ffi::types::GLuint {
        let depth_stencil = self.renderbuffer(ffi::DEPTH24_STENCIL8, width, height, samples);
        self.gl.FramebufferRenderbuffer(
            ffi::FRAMEBUFFER,
            ffi::DEPTH_STENCIL_ATTACHMENT,
            ffi::RENDERBUFFER,
            depth_stencil,
        );
        depth_stencil
    }

    pub fn make_current(&mut self, egl_context: &EGLContext) -> Result<(), MakeCurrentError> {
        unsafe { egl_context.make_current()? };
        // delayed destruction until the next frame rendering.
        self.cleanup();
        Ok(())
    }

    fn cleanup(&mut self) {
        // Free outdated buffer resources
        // TODO: Replace with `drain_filter` once it lands
        let mut i = 0;
        while i != self.buffers.len() {
            if self.buffers[i].dmabuf.is_gone() {
                let old = self.buffers.remove(i);
                self.forget_backing_store(old.fbo);
                self.drop_buffer(old);
            } else {
                i += 1;
            }
        }
    }

    /// A framebuffer is deleted: GL may hand its name to another backing
    /// store, which must not inherit its history.
    fn forget_backing_store(&mut self, fbo: ffi::types::GLuint) {
        for target in &mut self.view_targets {
            target.behind.remove(&fbo);
        }
    }

    fn drop_buffer(&self, gles_buffer: GlesFramebuffer) {
        unsafe {
            self.gl.DeleteFramebuffers(1, &gles_buffer.fbo as *const _);
            self.gl.DeleteRenderbuffers(1, &gles_buffer.rbo as *const _);
            self.gl
                .DeleteRenderbuffers(1, &gles_buffer.depth_stencil as *const _);
            ffi_egl::DestroyImageKHR(**self.egl_display.get_display_handle(), gles_buffer.image);
        }
    }
}

/// Whether the DRM device at `device` (its sysfs directory) has memory of its
/// own, read from what its kernel driver exposes. A driver that says nothing
/// is taken for integrated: the cautious guess.
fn sysfs_gpu_kind(device: &Path) -> GpuKind {
    let driver = std::fs::read_link(device.join("driver"))
        .ok()
        .and_then(|driver| {
            driver
                .file_name()
                .map(|name| name.to_string_lossy().into_owned())
        })
        .unwrap_or_default();
    let dedicated = match driver.as_str() {
        // amdgpu names the VRAM chips' vendor of dedicated GPUs only; an APU's
        // "VRAM" is a carve-out of system memory.
        "amdgpu" => device.join("mem_info_vram_vendor").exists(),
        // Intel's discrete GPUs have their own memory tiles under xe; i915
        // (also the driver of the first Arc cards) is taken for integrated.
        "xe" => device.join("tile0").join("vram0").exists(),
        "nouveau" | "nvidia" | "radeon" => true,
        _ => false,
    };
    if dedicated {
        GpuKind::Dedicated
    } else {
        GpuKind::Integrated
    }
}

impl Drop for GlesFramebufferImporter {
    fn drop(&mut self) {
        while let Some(buffer) = self.buffers.pop() {
            self.drop_buffer(buffer);
        }
        for (fbo, depth_stencil) in self.texture_framebuffers.drain() {
            unsafe {
                self.gl.DeleteFramebuffers(1, &fbo as *const _);
                self.gl.DeleteRenderbuffers(1, &depth_stencil as *const _);
            }
        }
        while let Some(target) = self.view_targets.pop() {
            self.drop_view_target(&target);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FULL: GlRect = (0, 0, 100, 100);

    #[test]
    fn a_backing_store_seen_first_receives_the_whole_frame() {
        let mut behind = HashMap::new();
        assert_eq!(catch_up(&mut behind, 1, (10, 10, 20, 20), FULL), Some(FULL));
    }

    #[test]
    fn each_backing_store_catches_up_on_what_it_missed() {
        let mut behind = HashMap::new();
        catch_up(&mut behind, 1, FULL, FULL);
        catch_up(&mut behind, 2, FULL, FULL);
        // Painted into 1, then 2, then 1 again.
        assert_eq!(
            catch_up(&mut behind, 1, (10, 10, 20, 20), FULL),
            Some((0, 0, 100, 100)),
            "1 missed the whole frame drawn into 2",
        );
        assert_eq!(
            catch_up(&mut behind, 2, (50, 50, 60, 60), FULL),
            Some((10, 10, 60, 60)),
            "2 missed what 1 received, and needs its own",
        );
        assert_eq!(
            catch_up(&mut behind, 1, (0, 0, 0, 0), FULL),
            Some((50, 50, 60, 60)),
            "1 missed only what 2 received",
        );
        assert_eq!(
            catch_up(&mut behind, 2, (0, 0, 0, 0), FULL),
            None,
            "nothing changed since 2 was brought up to date",
        );
    }

    const DEDICATED: Gpu = Gpu {
        kind: GpuKind::Dedicated,
        blits: true,
        max_samples: 8,
    };
    const INTEGRATED: Gpu = Gpu {
        kind: GpuKind::Integrated,
        blits: true,
        max_samples: 8,
    };
    const SOFTWARE: Gpu = Gpu {
        kind: GpuKind::Software,
        blits: true,
        max_samples: 4,
    };

    #[test]
    fn auto_antialiasing_weighs_the_gpu() {
        assert_eq!(DEDICATED.samples(Antialiasing::Auto), 4);
        assert_eq!(INTEGRATED.samples(Antialiasing::Auto), 2);
        assert_eq!(SOFTWARE.samples(Antialiasing::Auto), 1);
    }

    #[test]
    fn explicit_antialiasing_overrides_the_gpu() {
        for gpu in [DEDICATED, INTEGRATED, SOFTWARE] {
            assert_eq!(gpu.samples(Antialiasing::Off), 1);
            assert_eq!(gpu.samples(Antialiasing::X2), 2);
            assert_eq!(gpu.samples(Antialiasing::X4), 4);
        }
    }

    #[test]
    fn antialiasing_never_exceeds_what_the_gpu_takes() {
        let two = Gpu {
            kind: GpuKind::Dedicated,
            blits: true,
            max_samples: 2,
        };
        assert_eq!(two.samples(Antialiasing::X4), 2);
        assert_eq!(two.samples(Antialiasing::Auto), 2);
        let gles2 = Gpu {
            kind: GpuKind::Dedicated,
            blits: false,
            max_samples: 0,
        };
        assert_eq!(gles2.samples(Antialiasing::X4), 1);
    }

    #[test]
    fn gpu_kind_comes_from_the_driver_s_sysfs() {
        let root = std::env::temp_dir().join(format!("veshell-gpu-kind-{}", std::process::id()));
        let device = |name: &str, driver: &str, files: &[&str]| {
            let device = root.join(name);
            std::fs::create_dir_all(&device).unwrap();
            let driver_dir = root.join("drivers").join(driver);
            std::fs::create_dir_all(&driver_dir).unwrap();
            std::os::unix::fs::symlink(&driver_dir, device.join("driver")).unwrap();
            for file in files {
                let path = device.join(file);
                std::fs::create_dir_all(path.parent().unwrap()).unwrap();
                std::fs::write(path, "").unwrap();
            }
            device
        };
        let vega = device("vega", "amdgpu", &["mem_info_vram_vendor"]);
        let apu = device("apu", "amdgpu", &["mem_info_vram_total"]);
        let arc = device("arc", "xe", &["tile0/vram0"]);
        let iris = device("iris", "i915", &[]);
        let vc4 = device("vc4", "vc4", &[]);
        assert_eq!(sysfs_gpu_kind(&vega), GpuKind::Dedicated);
        assert_eq!(sysfs_gpu_kind(&apu), GpuKind::Integrated);
        assert_eq!(sysfs_gpu_kind(&arc), GpuKind::Dedicated);
        assert_eq!(sysfs_gpu_kind(&iris), GpuKind::Integrated);
        assert_eq!(sysfs_gpu_kind(&vc4), GpuKind::Integrated);
        assert_eq!(sysfs_gpu_kind(&root.join("missing")), GpuKind::Integrated);
        std::fs::remove_dir_all(&root).unwrap();
    }
}
