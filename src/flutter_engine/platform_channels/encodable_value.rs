#[repr(u8)]
#[derive(Debug)]
pub enum EncodableValue {
    Null = 0,
    Bool(bool),
    Int32(i32),
    Int64(i64),
    Double(f64),
    String(String),
    ByteList(Vec<u8>),
    Int32List(Vec<i32>),
    Int64List(Vec<i64>),
    DoubleList(Vec<f64>),
    List(Vec<EncodableValue>),
    Map(Vec<(EncodableValue, EncodableValue)>),
    Custom(CustomEncodableValue),
    FloatList(Vec<f32>),
}

impl EncodableValue {
    pub fn is_null(&self) -> bool {
        matches!(self, EncodableValue::Null)
    }

    pub fn long_value(&self) -> Option<i64> {
        match self {
            EncodableValue::Int32(v) => Some(*v as i64),
            EncodableValue::Int64(v) => Some(*v),
            _ => None,
        }
    }
}

// TODO: It should be generic over T, but the codec doesn't support custom encodable values,
// so I don't think it's worth implementing this because it's more work than it's worth.
#[derive(Eq, PartialEq, Debug)]
pub struct CustomEncodableValue {}

// impl<T: Any + Copy> CustomEncodableValue<T> {
//     pub fn new(value: &T) -> Self {
//         Self {
//             value: *value,
//         }
//     }
//
//     pub fn call(&self) -> &T {
//         &self.value
//     }
//
//     pub fn type_id(&self) -> TypeId {
//         self.value.type_id()
//     }
// }
