pub struct TrackpadScrollingManager {
    pub trackpad_scrolling: bool,
    pub pan_x: f64,
    pub pan_y: f64,
}
impl TrackpadScrollingManager {
    pub fn new() -> Self {
        Self {
            trackpad_scrolling: false,
            pan_x: 0.0,
            pan_y: 0.0,
        }
    }
    pub fn start_scrolling(&mut self) {
        self.trackpad_scrolling = true;
        self.pan_x = 0.0;
        self.pan_y = 0.0;
    }
    pub fn stop_scrolling(&mut self) {
        self.trackpad_scrolling = false;
    }
    pub fn update_pan(&mut self, delta_x: f64, delta_y: f64) {
        self.pan_x += delta_x;
        self.pan_y += delta_y;
    }
    pub fn reset_pan(&mut self) {
        self.pan_x = 0.0;
        self.pan_y = 0.0;
    }
}
