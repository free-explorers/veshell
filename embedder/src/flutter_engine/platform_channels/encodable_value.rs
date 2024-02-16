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

impl From<bool> for EncodableValue {
    fn from(value: bool) -> Self {
        EncodableValue::Bool(value)
    }
}

impl From<i32> for EncodableValue {
    fn from(value: i32) -> Self {
        EncodableValue::Int32(value)
    }
}

impl From<i64> for EncodableValue {
    fn from(value: i64) -> Self {
        EncodableValue::Int64(value)
    }
}

// For convenience.
impl From<u32> for EncodableValue {
    fn from(value: u32) -> Self {
        // I didn't choose i32 because a u32 can be larger than i32.
        // However, a i64 will always be able to hold a u32.
        EncodableValue::Int64(value as i64)
    }
}

// For convenience.
impl From<u64> for EncodableValue {
    fn from(value: u64) -> Self {
        // Let's hope the value is small enough to fit into an i64. Otherwise it will just panic.
        EncodableValue::Int64(value as i64)
    }
}

impl From<f64> for EncodableValue {
    fn from(value: f64) -> Self {
        EncodableValue::Double(value)
    }
}

impl From<String> for EncodableValue {
    fn from(value: String) -> Self {
        EncodableValue::String(value)
    }
}

// For convenience.
impl From<&str> for EncodableValue {
    fn from(value: &str) -> Self {
        EncodableValue::String(value.to_string())
    }
}

impl From<Vec<u8>> for EncodableValue {
    fn from(value: Vec<u8>) -> Self {
        EncodableValue::ByteList(value)
    }
}

impl From<Vec<i32>> for EncodableValue {
    fn from(value: Vec<i32>) -> Self {
        EncodableValue::Int32List(value)
    }
}

impl From<Vec<i64>> for EncodableValue {
    fn from(value: Vec<i64>) -> Self {
        EncodableValue::Int64List(value)
    }
}

// For convenience.
impl From<Vec<u32>> for EncodableValue {
    fn from(value: Vec<u32>) -> Self {
        EncodableValue::Int64List(value.into_iter().map(|v| v as i64).collect())
    }
}

// For convenience.
impl From<Vec<u64>> for EncodableValue {
    fn from(value: Vec<u64>) -> Self {
        EncodableValue::Int64List(value.into_iter().map(|v| v as i64).collect())
    }
}

impl From<Vec<f64>> for EncodableValue {
    fn from(value: Vec<f64>) -> Self {
        EncodableValue::DoubleList(value)
    }
}

impl From<Vec<EncodableValue>> for EncodableValue {
    fn from(value: Vec<EncodableValue>) -> Self {
        EncodableValue::List(value)
    }
}

// Unfortunately Rust doesn't have trait specialization,
// so we can create an EncodableValue::List using this method.
pub trait IntoEncodableValueList {
    fn into_encodable_value_list(self) -> EncodableValue;
}

impl<T> IntoEncodableValueList for Vec<T>
where
    T: Into<EncodableValue>,
{
    fn into_encodable_value_list(self) -> EncodableValue {
        self.into_iter()
            .map(|v| v.into())
            .collect::<Vec<EncodableValue>>()
            .into()
    }
}

impl From<Vec<(EncodableValue, EncodableValue)>> for EncodableValue {
    fn from(value: Vec<(EncodableValue, EncodableValue)>) -> Self {
        EncodableValue::Map(value)
    }
}

impl From<CustomEncodableValue> for EncodableValue {
    fn from(value: CustomEncodableValue) -> Self {
        EncodableValue::Custom(value)
    }
}

impl From<Vec<f32>> for EncodableValue {
    fn from(value: Vec<f32>) -> Self {
        EncodableValue::FloatList(value)
    }
}
