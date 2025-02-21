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

    pub fn map(&self) -> Option<&Vec<(EncodableValue, EncodableValue)>> {
        match self {
            EncodableValue::Map(v) => Some(v),
            _ => None,
        }
    }

    pub fn list(&self) -> Option<&Vec<EncodableValue>> {
        match self {
            EncodableValue::List(v) => Some(v),
            _ => None,
        }
    }

    pub fn string(&self) -> Option<&str> {
        match self {
            EncodableValue::String(v) => Some(v),
            _ => None,
        }
    }

    pub fn double(&self) -> Option<f64> {
        match self {
            EncodableValue::Double(v) => Some(*v),
            _ => None,
        }
    }

    pub fn bool(&self) -> Option<bool> {
        match self {
            EncodableValue::Bool(v) => Some(*v),
            _ => None,
        }
    }

    pub fn int32(&self) -> Option<i32> {
        match self {
            EncodableValue::Int32(v) => Some(*v),
            _ => None,
        }
    }

    pub fn int64(&self) -> Option<i64> {
        match self {
            EncodableValue::Int64(v) => Some(*v),
            _ => None,
        }
    }

    pub fn byte_list(&self) -> Option<&Vec<u8>> {
        match self {
            EncodableValue::ByteList(v) => Some(v),
            _ => None,
        }
    }

    pub fn int32_list(&self) -> Option<&Vec<i32>> {
        match self {
            EncodableValue::Int32List(v) => Some(v),
            _ => None,
        }
    }
}

// TODO: It should be generic over T, but the codec doesn't support custom encodable values,
// so I don't think it's worth implementing this because it's more work than it's worth.
#[derive(Eq, PartialEq, Debug)]
pub struct CustomEncodableValue {}
