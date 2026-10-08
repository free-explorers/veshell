//! Producer-owned shared-memory buffers for the PipeWire screen-cast
//! fallback transport.
//!
//! The dmabuf path (see [`super::pipewire`]) renders straight into a GPU
//! buffer; when a consumer only understands shared memory, the producer has
//! to allocate the `MemFd` buffers itself (`PW_STREAM_FLAG_ALLOC_BUFFERS`),
//! which is what this module provides: a sealed memfd plus its writable
//! mapping. The consumer receives a duplicated fd through the negotiated
//! SPA buffer; this process keeps the mapping to copy rendered frames in.

use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::ptr;

/// One producer-owned shared-memory buffer: a sealed, fixed-size memfd and
/// its writable mapping.
pub struct ShmBuffer {
    fd: OwnedFd,
    mapping: *mut u8,
    len: usize,
    /// Row stride in bytes (width * 4).
    pub stride: i32,
    /// Total frame length in bytes (stride * height).
    pub size: u32,
}

impl ShmBuffer {
    /// Allocates a sealed memfd sized for an RGBA frame of `width`x`height`
    /// and maps it writable for the producer to fill.
    pub fn allocate(width: u32, height: u32) -> Result<Self, String> {
        let stride = width
            .checked_mul(4)
            .ok_or_else(|| "SHM stride overflows".to_string())?;
        let size = stride
            .checked_mul(height)
            .ok_or_else(|| "SHM buffer size overflows".to_string())?;
        if size == 0 {
            return Err("SHM buffer size must be positive".to_string());
        }

        let name =
            std::ffi::CString::new("veshell-screen-cast").expect("static name has no interior nul");
        // SAFETY: the name is a valid C string; the flags are valid memfd
        // flags. The returned fd owns the memfd.
        let raw_fd = unsafe {
            libc::memfd_create(name.as_ptr(), libc::MFD_CLOEXEC | libc::MFD_ALLOW_SEALING)
        };
        if raw_fd < 0 {
            return Err(format!(
                "memfd_create failed: {}",
                std::io::Error::last_os_error()
            ));
        }
        // SAFETY: raw_fd is a freshly created, owned file descriptor.
        let fd = unsafe { OwnedFd::from_raw_fd(raw_fd) };

        // SAFETY: fd is a valid memfd and size fits in off_t.
        if unsafe { libc::ftruncate(fd.as_raw_fd(), size as libc::off_t) } != 0 {
            return Err(format!(
                "Unable to size the SHM buffer: {}",
                std::io::Error::last_os_error()
            ));
        }

        // Sealing the fd against shrink/grow is what lets the consumer trust
        // the advertised size. Non-fatal if the kernel refuses it.
        let seals = libc::F_SEAL_SHRINK | libc::F_SEAL_GROW | libc::F_SEAL_SEAL;
        // SAFETY: fd is a valid memfd; F_ADD_SEALS takes an integer seal mask.
        if unsafe { libc::fcntl(fd.as_raw_fd(), libc::F_ADD_SEALS, seals) } != 0 {
            tracing::debug!(
                error = %std::io::Error::last_os_error(),
                "Unable to seal the screen-cast SHM buffer"
            );
        }

        // SAFETY: fd is a valid memfd of exactly `size` bytes; the mapping is
        // released in Drop.
        let mapping = unsafe {
            libc::mmap(
                ptr::null_mut(),
                size as usize,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_SHARED,
                fd.as_raw_fd(),
                0,
            )
        };
        if mapping == libc::MAP_FAILED {
            return Err(format!(
                "Unable to map the SHM buffer: {}",
                std::io::Error::last_os_error()
            ));
        }

        Ok(Self {
            fd,
            mapping: mapping as *mut u8,
            len: size as usize,
            stride: stride as i32,
            size,
        })
    }

    /// The raw memfd to hand to PipeWire (it duplicates the fd).
    pub fn as_raw_fd(&self) -> RawFd {
        self.fd.as_raw_fd()
    }

    /// Copies one RGBA frame into the mapping. `frame` must match the
    /// negotiated size exactly; callers check that before copying.
    pub fn copy_frame(&self, frame: &[u8]) {
        let copied = frame.len().min(self.len);
        // SAFETY: the mapping is valid for `len` bytes and exclusively
        // accessed while the producer owns the dequeued PipeWire buffer.
        unsafe {
            ptr::copy_nonoverlapping(frame.as_ptr(), self.mapping, copied);
        }
    }

    /// Total frame length the mapping accepts.
    pub fn len(&self) -> usize {
        self.len
    }
}

impl Drop for ShmBuffer {
    fn drop(&mut self) {
        // SAFETY: the mapping was created by mmap with this exact pointer and
        // length, and is not used past Drop.
        unsafe {
            libc::munmap(self.mapping as *mut libc::c_void, self.len);
        }
    }
}

// The raw mapping pointer is only touched on the compositor loop thread.
unsafe impl Send for ShmBuffer {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shm_buffer_is_mapped_and_copies_frames() {
        let buffer = ShmBuffer::allocate(4, 2).expect("SHM allocation");
        assert_eq!(buffer.stride, 16);
        assert_eq!(buffer.size, 32);
        let frame: Vec<u8> = (0u8..32).collect();
        buffer.copy_frame(&frame);

        // SAFETY: the mapping is valid for `len` bytes and the test owns it.
        let mapped = unsafe { std::slice::from_raw_parts(buffer.mapping, buffer.len()) };
        assert_eq!(mapped, frame.as_slice());
    }
}
