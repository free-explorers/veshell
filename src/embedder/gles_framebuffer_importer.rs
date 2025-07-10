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

use core::ffi::{c_char, CStr};

use smithay::backend::egl::context::{GlAttributes, GlProfile, PixelFormatRequirements};
use smithay::backend::egl::EGLDisplay;
use smithay::backend::{
    allocator::dmabuf::{Dmabuf, WeakDmabuf},
    egl::{
        self,
        ffi::egl::{self as ffi_egl, types::EGLImage},
        EGLContext, MakeCurrentError,
    },
    renderer::gles::{ffi, GlesError},
};
use tracing::{debug, info, trace};

pub struct GlesFramebufferImporter {
    pub(crate) gl: ffi::Gles2,
    egl_context: EGLContext,

    // caches
    buffers: Vec<GlesFramebuffer>,
}

#[derive(Debug, Clone)]
struct GlesFramebuffer {
    dmabuf: WeakDmabuf,
    image: EGLImage,
    rbo: ffi::types::GLuint,
    fbo: ffi::types::GLuint,
}

impl GlesFramebufferImporter {
    pub unsafe fn new(root_egl_context: &EGLContext) -> Result<Self, GlesError> {
        unsafe { root_egl_context.make_current()? };

        let gl = ffi::Gles2::load_with(|s| egl::get_proc_address(s) as *const _);
        let egl_display = root_egl_context.display().clone();
        let gl_attributes = GlAttributes {
            version: (2, 0),
            profile: Some(GlProfile::Core),
            debug: false,
            vsync: false,
        };
        let pixel_format_requirements = PixelFormatRequirements::_8_bit();
        let main_egl_context = EGLContext::new_shared_with_config(
            &egl_display,
            &root_egl_context,
            gl_attributes,
            pixel_format_requirements,
        )
        .map_err(|e| GlesError::CreateShaderObject)?;

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
            egl_context: main_egl_context,
            buffers: vec![],
        })
    }

    pub fn import_framebuffer(&mut self, dmabuf: Dmabuf) -> Result<u32, GlesError> {
        debug!(
            "import_framebuffer thread: {:?}",
            std::thread::current().id()
        );
        self.make_current()?;
        debug!("after make_current");

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
                let image = self
                    .egl_context
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
                    let status = self.gl.CheckFramebufferStatus(ffi::FRAMEBUFFER);
                    self.gl.BindFramebuffer(ffi::FRAMEBUFFER, 0);

                    if status != ffi::FRAMEBUFFER_COMPLETE {
                        //TODO wrap image and drop here
                        return Err(GlesError::FramebufferBindingError);
                    }

                    let buf = GlesFramebuffer {
                        dmabuf: dmabuf.weak(),
                        image,
                        rbo,
                        fbo,
                    };

                    self.buffers.push(buf);

                    Ok(fbo)
                }
            })?;

        self.make_current()?;
        Ok(fbo)
    }

    pub fn make_current(&mut self) -> Result<(), MakeCurrentError> {
        unsafe { self.egl_context.make_current()? };
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
            ffi_egl::DestroyImageKHR(
                **self.egl_context.display().get_display_handle(),
                gles_buffer.image,
            );
        }
    }
}

impl Drop for GlesFramebufferImporter {
    fn drop(&mut self) {
        while let Some(buffer) = self.buffers.pop() {
            self.drop_buffer(buffer);
        }
    }
}
