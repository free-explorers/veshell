use tracing::error;

#[derive(Copy, Clone, Eq, PartialEq)]
pub struct TextRange {
    base: usize,
    extent: usize,
}

impl TextRange {
    pub fn new(base: usize, extent: usize) -> Self {
        Self { base, extent }
    }

    pub fn new_position(position: usize) -> Self {
        Self { base: position, extent: position }
    }

    pub fn base(&self) -> usize {
        self.base
    }

    pub fn set_base(&mut self, base: usize) {
        self.base = base;
    }

    pub fn extent(&self) -> usize {
        self.extent
    }

    pub fn set_extent(&mut self, extent: usize) {
        self.extent = extent;
    }

    pub fn start(&self) -> usize {
        self.base.min(self.extent)
    }

    pub fn set_start(&mut self, start: usize) {
        if self.base <= self.extent {
            self.base = start;
        } else {
            self.extent = start;
        }
    }

    pub fn end(&self) -> usize {
        self.base.max(self.extent)
    }

    pub fn set_end(&mut self, end: usize) {
        if self.base <= self.extent {
            self.extent = end;
        } else {
            self.base = end;
        }
    }

    pub fn position(&self) -> usize {
        if self.base != self.extent {
            error!("base != extent");
        }
        self.extent
    }

    pub fn length(&self) -> usize {
        self.end() - self.start()
    }

    pub fn collapsed(&self) -> bool {
        self.base == self.extent
    }

    pub fn reversed(&self) -> bool {
        self.base > self.extent
    }

    pub fn contains_position(&self, position: usize) -> bool {
        position >= self.start() && position <= self.end()
    }

    pub fn contains_range(&self, other: &TextRange) -> bool {
        other.start() >= self.start() && other.end() <= self.end()
    }
}
