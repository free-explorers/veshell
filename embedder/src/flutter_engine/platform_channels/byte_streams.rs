pub trait ByteStreamReader {
    fn read_byte(&mut self) -> u8;
    fn read_bytes(&mut self, buffer: &mut [u8], count: usize);
    fn read_alignment(&mut self, alignment: u8);

    fn read_i32(&mut self) -> i32 {
        let mut buffer = [0u8; 4];
        self.read_bytes(buffer.as_mut(), 4);
        i32::from_ne_bytes(buffer)
    }

    fn read_i64(&mut self) -> i64 {
        let mut buffer = [0u8; 8];
        self.read_bytes(buffer.as_mut(), 8);
        i64::from_ne_bytes(buffer)
    }

    fn read_double(&mut self) -> f64 {
        let mut buffer = [0u8; 8];
        self.read_bytes(buffer.as_mut(), 8);
        f64::from_ne_bytes(buffer)
    }
}

pub trait ByteStreamWriter {
    fn write_byte(&mut self, value: u8);
    fn write_bytes(&mut self, buffer: &[u8], count: usize);
    fn write_alignment(&mut self, alignment: u8);

    fn write_i32(&mut self, value: i32) {
        self.write_bytes(&value.to_ne_bytes(), 4);
    }

    fn write_i64(&mut self, value: i64) {
        self.write_bytes(&value.to_ne_bytes(), 8);
    }

    fn write_double(&mut self, value: f64) {
        self.write_bytes(&value.to_ne_bytes(), 8);
    }
}
