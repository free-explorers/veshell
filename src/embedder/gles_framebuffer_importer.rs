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
//! # Multisampling
//!
//! Impeller antialiases paths and clips through multisampling, but only
//! multisamples a framebuffer the embedder hands it when the driver resolves
//! implicitly (`GL_EXT_multisampled_render_to_texture`), which desktop Mesa
//! does not. Drawn straight into a single-sample backing store, every edge
//! that is not an SDF shape is aliased: clipped windows and images, charts,
//! custom paths.
//!
//! So, as Flutter's own GTK embedder does, Flutter renders into a
//! multisampled framebuffer of ours ([`MsaaTarget`]), which
//! [`GlesFramebufferImporter::resolve`] blits into the backing store once
//! the frame is submitted. Frames are rendered one view after the other on
//! the raster thread, each resolved before the next starts, so views of one
//! size share a target.
//!
//! The sample count follows the `theme.antialiasing` setting
//! ([`set_antialiasing`]); `auto` weighs the GPU (see [`GpuKind`]). A change
//! applies from the next frame. Drivers without GLES 3 multisampling render
//! into the backing store directly.

use core::ffi::{c_char, CStr};

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU8, Ordering};
use std::time::{Duration, Instant};

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
use tracing::{info, trace};

use crate::settings::Antialiasing;

/// How long a multisampled target outlives its last frame. A screen that
/// stays still for longer gives its memory back and allocates it again when
/// it next changes; a resized or unplugged one does not keep it at all.
const MSAA_TARGET_IDLE_LIFETIME: Duration = Duration::from_secs(10);

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

/// The GPU's kind and how many samples its multisampled renderbuffers take
/// (0 without GLES 3).
#[derive(Debug, Clone, Copy)]
struct Gpu {
    kind: GpuKind,
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
    /// The sample count the cached framebuffers are set up for.
    samples: i32,

    // caches
    buffers: Vec<GlesFramebuffer>,
    /// The framebuffers made by [`Self::import_texture`], released with
    /// their backing store.
    texture_framebuffers: HashMap<ffi::types::GLuint, TextureFramebuffer>,
    msaa_targets: Vec<MsaaTarget>,
}

#[derive(Debug, Clone)]
struct GlesFramebuffer {
    dmabuf: WeakDmabuf,
    image: EGLImage,
    rbo: ffi::types::GLuint,
    /// 0 when Flutter renders into a multisampled target instead.
    depth_stencil: ffi::types::GLuint,
    fbo: ffi::types::GLuint,
    width: i32,
    height: i32,
}

#[derive(Debug, Clone, Copy)]
struct TextureFramebuffer {
    /// 0 when Flutter renders into a multisampled target instead.
    depth_stencil: ffi::types::GLuint,
    width: i32,
    height: i32,
}

/// A multisampled framebuffer Flutter renders into, for one size.
#[derive(Debug)]
struct MsaaTarget {
    width: i32,
    height: i32,
    fbo: ffi::types::GLuint,
    color: ffi::types::GLuint,
    depth_stencil: ffi::types::GLuint,
    last_used: Instant,
}

/// The framebuffer Flutter renders a backing store into.
#[derive(Debug, Clone, Copy)]
pub struct ImportedTarget {
    /// The framebuffer handed to Flutter.
    pub render_fbo: ffi::types::GLuint,
    /// The blit that moves the rendered frame into the backing store, when
    /// Flutter renders multisampled.
    pub resolve: Option<Resolve>,
}

/// A multisample resolve, run once Flutter has submitted the frame.
#[derive(Debug, Clone, Copy)]
pub struct Resolve {
    from: ffi::types::GLuint,
    to: ffi::types::GLuint,
    width: i32,
    height: i32,
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
            samples: 1,
            buffers: vec![],
            texture_framebuffers: HashMap::new(),
            msaa_targets: vec![],
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
        texture: &GlesTexture,
    ) -> Result<(ffi::types::GLuint, ImportedTarget), GlesError> {
        self.make_current(egl_context)?;
        self.update_sampling();

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
            let depth_stencil = if self.samples > 1 {
                0
            } else {
                self.attach_depth_stencil(size.w, size.h, 1)
            };
            let status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

            if status != ffi::FRAMEBUFFER_COMPLETE {
                self.gl.DeleteFramebuffers(1, &fbo as *const _);
                self.gl.DeleteRenderbuffers(1, &depth_stencil as *const _);
                return Err(GlesError::FramebufferBindingError);
            }
            self.texture_framebuffers.insert(
                fbo,
                TextureFramebuffer {
                    depth_stencil,
                    width: size.w,
                    height: size.h,
                },
            );

            trace!(
                texture_id = texture.tex_id(),
                fbo,
                "Created framebuffer for Flutter texture"
            );
            match self.render_target(fbo, size.w, size.h) {
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
        unsafe {
            self.gl.DeleteFramebuffers(1, &fbo as *const _);
            if let Some(framebuffer) = self.texture_framebuffers.remove(&fbo) {
                self.gl
                    .DeleteRenderbuffers(1, &framebuffer.depth_stencil as *const _);
            }
        }
    }

    pub fn import_framebuffer(
        &mut self,
        egl_context: &EGLContext,
        dmabuf: Dmabuf,
    ) -> Result<ImportedTarget, GlesError> {
        self.make_current(egl_context)?;
        self.update_sampling();
        let multisampled = self.samples > 1;

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
                let (width, height) = (dmabuf.width() as i32, dmabuf.height() as i32);

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
                    let depth_stencil = if multisampled {
                        0
                    } else {
                        self.attach_depth_stencil(width, height, 1)
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
                        width,
                        height,
                    };

                    self.buffers.push(buf);

                    Ok(fbo)
                }
            })?;

        let target = self.render_target(fbo, dmabuf.width() as i32, dmabuf.height() as i32)?;
        self.make_current(egl_context)?;
        Ok(target)
    }

    /// Moves a multisampled frame into its backing store.
    ///
    /// Called on the raster thread once Flutter has submitted the frame, with
    /// its context current and before the fence that tells the compositor the
    /// frame is ready. The GL state the blit depends on is restored after it:
    /// Impeller tracks some of its own.
    pub fn resolve(&self, resolve: Resolve) {
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

            self.gl.BindFramebuffer(ffi::READ_FRAMEBUFFER, resolve.from);
            self.gl.BindFramebuffer(ffi::DRAW_FRAMEBUFFER, resolve.to);
            self.gl.BlitFramebuffer(
                0,
                0,
                resolve.width,
                resolve.height,
                0,
                0,
                resolve.width,
                resolve.height,
                ffi::COLOR_BUFFER_BIT,
                ffi::NEAREST,
            );
            // Nothing reads the samples again: the next frame clears them.
            let attachments = [ffi::COLOR_ATTACHMENT0, ffi::DEPTH_STENCIL_ATTACHMENT];
            self.gl.InvalidateFramebuffer(
                ffi::READ_FRAMEBUFFER,
                attachments.len() as i32,
                attachments.as_ptr(),
            );

            self.gl
                .BindFramebuffer(ffi::READ_FRAMEBUFFER, read_binding as ffi::types::GLuint);
            self.gl
                .BindFramebuffer(ffi::DRAW_FRAMEBUFFER, draw_binding as ffi::types::GLuint);
            if scissor {
                self.gl.Enable(ffi::SCISSOR_TEST);
            }
        }
    }

    /// The framebuffer Flutter renders a backing store whose framebuffer is
    /// `fbo` into.
    fn render_target(
        &mut self,
        fbo: ffi::types::GLuint,
        width: i32,
        height: i32,
    ) -> Result<ImportedTarget, GlesError> {
        if self.samples <= 1 {
            return Ok(ImportedTarget {
                render_fbo: fbo,
                resolve: None,
            });
        }
        let msaa_fbo = self.msaa_target(width, height)?;
        Ok(ImportedTarget {
            render_fbo: msaa_fbo,
            resolve: Some(Resolve {
                from: msaa_fbo,
                to: fbo,
                width,
                height,
            }),
        })
    }

    /// Brings the cached framebuffers to the sample count the setting and the
    /// GPU call for, between two frames.
    ///
    /// Multisampled, Flutter's depth and stencil live in the multisampled
    /// target; single-sample, every backing store framebuffer needs its own.
    fn update_sampling(&mut self) {
        let samples = self.gpu().samples(antialiasing());
        if samples == self.samples {
            return;
        }
        info!(
            from = self.samples,
            to = samples,
            "Changing Flutter's multisampling"
        );
        self.samples = samples;
        for target in std::mem::take(&mut self.msaa_targets) {
            self.drop_msaa_target(&target);
        }

        let wants_depth_stencil = samples <= 1;
        let mut buffers = std::mem::take(&mut self.buffers);
        for buffer in &mut buffers {
            buffer.depth_stencil = unsafe {
                self.swap_depth_stencil(
                    buffer.fbo,
                    buffer.depth_stencil,
                    wants_depth_stencil,
                    buffer.width,
                    buffer.height,
                )
            };
        }
        self.buffers = buffers;
        let mut framebuffers = std::mem::take(&mut self.texture_framebuffers);
        for (fbo, framebuffer) in &mut framebuffers {
            framebuffer.depth_stencil = unsafe {
                self.swap_depth_stencil(
                    *fbo,
                    framebuffer.depth_stencil,
                    wants_depth_stencil,
                    framebuffer.width,
                    framebuffer.height,
                )
            };
        }
        self.texture_framebuffers = framebuffers;
    }

    /// Gives framebuffer `fbo` a single-sample depth/stencil renderbuffer, or
    /// takes its `current` one away. Returns the renderbuffer it is left with
    /// (0 for none).
    unsafe fn swap_depth_stencil(
        &self,
        fbo: ffi::types::GLuint,
        current: ffi::types::GLuint,
        wanted: bool,
        width: i32,
        height: i32,
    ) -> ffi::types::GLuint {
        if wanted == (current != 0) {
            return current;
        }
        self.gl.BindFramebuffer(ffi::FRAMEBUFFER, fbo);
        let depth_stencil = if wanted {
            self.attach_depth_stencil(width, height, 1)
        } else {
            self.gl.FramebufferRenderbuffer(
                ffi::FRAMEBUFFER,
                ffi::DEPTH_STENCIL_ATTACHMENT,
                ffi::RENDERBUFFER,
                0,
            );
            self.gl.DeleteRenderbuffers(1, &current as *const _);
            0
        };
        self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);
        depth_stencil
    }

    /// The multisampled framebuffer for frames of `width`x`height`, made on
    /// first use; targets left unused are released.
    fn msaa_target(&mut self, width: i32, height: i32) -> Result<ffi::types::GLuint, GlesError> {
        let now = Instant::now();
        let mut i = 0;
        while i != self.msaa_targets.len() {
            let target = &self.msaa_targets[i];
            let fits = target.width == width && target.height == height;
            if !fits && now.duration_since(target.last_used) > MSAA_TARGET_IDLE_LIFETIME {
                let target = self.msaa_targets.remove(i);
                self.drop_msaa_target(&target);
            } else {
                i += 1;
            }
        }
        if let Some(target) = self
            .msaa_targets
            .iter_mut()
            .find(|target| target.width == width && target.height == height)
        {
            target.last_used = now;
            return Ok(target.fbo);
        }

        let samples = self.samples;
        unsafe {
            let mut color = 0;
            self.gl.GenRenderbuffers(1, &mut color as *mut _);
            self.gl.BindRenderbuffer(ffi::RENDERBUFFER, color);
            self.gl.RenderbufferStorageMultisample(
                ffi::RENDERBUFFER,
                samples,
                ffi::RGBA8,
                width,
                height,
            );
            self.gl.BindRenderbuffer(ffi::RENDERBUFFER, 0);

            let mut fbo = 0;
            self.gl.GenFramebuffers(1, &mut fbo as *mut _);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, fbo);
            self.gl.FramebufferRenderbuffer(
                ffi::FRAMEBUFFER,
                ffi::COLOR_ATTACHMENT0,
                ffi::RENDERBUFFER,
                color,
            );
            let depth_stencil = self.attach_depth_stencil(width, height, samples);
            let status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
            self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

            let target = MsaaTarget {
                width,
                height,
                fbo,
                color,
                depth_stencil,
                last_used: now,
            };
            if status != ffi::FRAMEBUFFER_COMPLETE {
                self.drop_msaa_target(&target);
                return Err(GlesError::FramebufferBindingError);
            }
            info!(width, height, samples, "Created a multisampled target");
            self.msaa_targets.push(target);
            Ok(fbo)
        }
    }

    fn drop_msaa_target(&self, target: &MsaaTarget) {
        unsafe {
            self.gl.DeleteFramebuffers(1, &target.fbo as *const _);
            self.gl.DeleteRenderbuffers(1, &target.color as *const _);
            self.gl
                .DeleteRenderbuffers(1, &target.depth_stencil as *const _);
        }
    }

    /// The GPU Flutter renders on. Needs a current context.
    fn gpu(&mut self) -> Gpu {
        if let Some(gpu) = self.gpu {
            return gpu;
        }
        let (renderer, max_samples) = unsafe {
            let renderer = CStr::from_ptr(self.gl.GetString(ffi::RENDERER) as *const c_char)
                .to_string_lossy()
                .to_ascii_lowercase();
            let mut major = 0;
            self.gl.GetIntegerv(ffi::MAJOR_VERSION, &mut major);
            let mut max_samples = 0;
            if major >= 3 {
                self.gl.GetIntegerv(ffi::MAX_SAMPLES, &mut max_samples);
            }
            (renderer, max_samples)
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
        let gpu = Gpu { kind, max_samples };
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
        let mut depth_stencil = 0;
        self.gl.GenRenderbuffers(1, &mut depth_stencil as *mut _);
        self.gl.BindRenderbuffer(ffi::RENDERBUFFER, depth_stencil);
        if samples > 1 {
            self.gl.RenderbufferStorageMultisample(
                ffi::RENDERBUFFER,
                samples,
                ffi::DEPTH24_STENCIL8,
                width,
                height,
            );
        } else {
            self.gl
                .RenderbufferStorage(ffi::RENDERBUFFER, ffi::DEPTH24_STENCIL8, width, height);
        }
        self.gl.BindRenderbuffer(ffi::RENDERBUFFER, 0);
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
                self.drop_buffer(old);
            } else {
                i += 1;
            }
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
        for (fbo, framebuffer) in self.texture_framebuffers.drain() {
            unsafe {
                self.gl.DeleteFramebuffers(1, &fbo as *const _);
                self.gl
                    .DeleteRenderbuffers(1, &framebuffer.depth_stencil as *const _);
            }
        }
        while let Some(target) = self.msaa_targets.pop() {
            self.drop_msaa_target(&target);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const DEDICATED: Gpu = Gpu {
        kind: GpuKind::Dedicated,
        max_samples: 8,
    };
    const INTEGRATED: Gpu = Gpu {
        kind: GpuKind::Integrated,
        max_samples: 8,
    };
    const SOFTWARE: Gpu = Gpu {
        kind: GpuKind::Software,
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
            max_samples: 2,
        };
        assert_eq!(two.samples(Antialiasing::X4), 2);
        assert_eq!(two.samples(Antialiasing::Auto), 2);
        let gles2 = Gpu {
            kind: GpuKind::Dedicated,
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
