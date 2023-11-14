use smithay::backend::renderer::gles::GlesTexture;

#[derive(Default, Debug)]
pub struct TextureSwapChain {
    pub newest: Option<GlesTexture>,
    in_use: Option<GlesTexture>,
}

impl TextureSwapChain {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn commit(&mut self, texture: GlesTexture) {
        self.newest = Some(texture);
    }

    pub fn start_read(&mut self) -> GlesTexture {
        self.in_use = self.newest.clone();
        self.in_use.clone().unwrap()
    }

    pub fn end_read(&mut self) {
        self.in_use = None;
    }
}
