use std::cmp::Ordering;

use crate::flutter_engine::platform_channels::byte_streams::{ByteStreamReader, ByteStreamWriter};
use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

#[allow(non_camel_case_types)]
#[repr(u8)]
enum EncodedType {
    kNull = 0,
    kTrue,
    kFalse,
    kInt32,
    kInt64,
    // No longer used. If encountered, treat as kString.
    kLargeInt,
    kFloat64,
    kString,
    kUInt8List,
    kInt32List,
    kInt64List,
    kFloat64List,
    kList,
    kMap,
    kFloat32List,
}

impl TryFrom<u8> for EncodedType {
    type Error = ();

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(EncodedType::kNull),
            1 => Ok(EncodedType::kTrue),
            2 => Ok(EncodedType::kFalse),
            3 => Ok(EncodedType::kInt32),
            4 => Ok(EncodedType::kInt64),
            5 => Ok(EncodedType::kLargeInt),
            6 => Ok(EncodedType::kFloat64),
            7 => Ok(EncodedType::kString),
            8 => Ok(EncodedType::kUInt8List),
            9 => Ok(EncodedType::kInt32List),
            10 => Ok(EncodedType::kInt64List),
            11 => Ok(EncodedType::kFloat64List),
            12 => Ok(EncodedType::kList),
            13 => Ok(EncodedType::kMap),
            14 => Ok(EncodedType::kFloat32List),
            _ => Err(()),
        }
    }
}

impl EncodableValue {
    fn encoded_type_for_value(&self) -> EncodedType {
        match self {
            EncodableValue::Null => EncodedType::kNull,
            EncodableValue::Bool(true) => EncodedType::kTrue,
            EncodableValue::Bool(false) => EncodedType::kFalse,
            EncodableValue::Int32(_) => EncodedType::kInt32,
            EncodableValue::Int64(_) => EncodedType::kInt64,
            EncodableValue::Double(_) => EncodedType::kFloat64,
            EncodableValue::String(_) => EncodedType::kString,
            EncodableValue::ByteList(_) => EncodedType::kUInt8List,
            EncodableValue::Int32List(_) => EncodedType::kInt32List,
            EncodableValue::Int64List(_) => EncodedType::kInt64List,
            EncodableValue::DoubleList(_) => EncodedType::kFloat64List,
            EncodableValue::List(_) => EncodedType::kList,
            EncodableValue::Map(_) => EncodedType::kMap,
            EncodableValue::FloatList(_) => EncodedType::kFloat32List,
            EncodableValue::Custom(_) => {
                eprintln!("Custom types are not supported in StandardCodecSerializer");
                EncodedType::kNull
            }
        }
    }
}

#[derive(Default, Copy, Clone)]
pub(crate) struct StandardCodecSerializer;

impl StandardCodecSerializer {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn read_value(&self, stream: &mut dyn ByteStreamReader) -> EncodableValue {
        let type_ = stream.read_byte();
        self.read_value_of_type(type_, stream)
    }

    pub fn write_value(&self, encodable_value: &EncodableValue, stream: &mut dyn ByteStreamWriter) {
        stream.write_byte(encodable_value.encoded_type_for_value() as u8);

        match encodable_value {
            EncodableValue::Null => {}
            EncodableValue::Bool(_) => {}
            EncodableValue::Int32(value) => stream.write_i32(*value),
            EncodableValue::Int64(value) => stream.write_i64(*value),
            EncodableValue::Double(value) => {
                stream.write_alignment(8);
                stream.write_double(*value);
            }
            EncodableValue::String(value) => {
                let size = value.len();
                self.write_size(size, stream);
                if size > 0 {
                    stream.write_bytes(value.as_bytes(), size);
                }
            }
            // TODO: Move, don't clone.
            EncodableValue::ByteList(value) => self.write_vector(value.clone(), stream),
            EncodableValue::Int32List(value) => self.write_vector(value.clone(), stream),
            EncodableValue::Int64List(value) => self.write_vector(value.clone(), stream),
            EncodableValue::DoubleList(value) => self.write_vector(value.clone(), stream),
            EncodableValue::List(list) => {
                self.write_size(list.len(), stream);
                for value in list {
                    self.write_value(value, stream);
                }
            }
            EncodableValue::Map(map) => {
                self.write_size(map.len(), stream);
                for (key, value) in map.iter() {
                    self.write_value(key, stream);
                    self.write_value(value, stream);
                }
            }
            EncodableValue::Custom(_) => {
                eprintln!("Unhandled custom type in StandardCodecSerializer::WriteValue.\
                Custom types require codec extensions.");
            }
            EncodableValue::FloatList(value) => self.write_vector(value.clone(), stream),
        }
    }

    fn read_value_of_type(&self, type_: u8, stream: &mut dyn ByteStreamReader) -> EncodableValue {
        let type_ = if let Ok(type_) = type_.try_into() {
            type_
        } else {
            return EncodableValue::Null;
        };

        match type_ {
            EncodedType::kNull => EncodableValue::Null,
            EncodedType::kTrue => EncodableValue::Bool(true),
            EncodedType::kFalse => EncodableValue::Bool(false),
            EncodedType::kInt32 => EncodableValue::Int32(stream.read_i32()),
            EncodedType::kInt64 => EncodableValue::Int64(stream.read_i64()),
            EncodedType::kFloat64 => {
                stream.read_alignment(8);
                EncodableValue::Double(stream.read_double())
            }
            EncodedType::kLargeInt | EncodedType::kString => {
                let size = self.read_size(stream);
                let mut string_value = vec![0; size];
                stream.read_bytes(&mut string_value, size);
                EncodableValue::String(String::from_utf8(string_value).unwrap())
            }
            EncodedType::kUInt8List => self.read_vector::<u8>(stream),
            EncodedType::kInt32List => self.read_vector::<i32>(stream),
            EncodedType::kInt64List => self.read_vector::<i64>(stream),
            EncodedType::kFloat64List => self.read_vector::<f64>(stream),
            EncodedType::kList => {
                let length = self.read_size(stream);
                let mut list_value = Vec::with_capacity(length);
                for _ in 0..length {
                    list_value.push(self.read_value(stream));
                }
                EncodableValue::List(list_value)
            }
            EncodedType::kMap => {
                let length = self.read_size(stream);
                let mut map_value = Vec::with_capacity(length);
                for _ in 0..length {
                    let key = self.read_value(stream);
                    let value = self.read_value(stream);
                    map_value.push((key, value));
                }
                EncodableValue::Map(map_value)
            }
            EncodedType::kFloat32List => self.read_vector::<f32>(stream),
        }
    }

    fn read_size(&self, stream: &mut dyn ByteStreamReader) -> usize {
        let byte = stream.read_byte();
        match byte.cmp(&254) {
            Ordering::Less => byte as usize,
            Ordering::Equal => {
                let mut value = [0; 2];
                stream.read_bytes(&mut value, 2);
                u16::from_ne_bytes(value) as usize
            }
            Ordering::Greater => {
                let mut value = [0; 4];
                stream.read_bytes(&mut value, 4);
                u32::from_ne_bytes(value) as usize
            }
        }
    }

    fn write_size(&self, size: usize, stream: &mut dyn ByteStreamWriter) {
        if size < 254 {
            stream.write_byte(size as u8);
        } else if size <= u16::MAX as usize {
            stream.write_byte(254);
            stream.write_bytes(&(size as u16).to_ne_bytes(), 2);
        } else {
            stream.write_byte(255);
            stream.write_bytes(&(size as u32).to_ne_bytes(), 4);
        }
    }

    fn read_vector<T>(&self, stream: &mut dyn ByteStreamReader) -> EncodableValue {
        let count = self.read_size(stream);
        let mut vector = vec![0; count];
        let type_size = std::mem::size_of::<T>();
        if type_size > 1 {
            stream.read_alignment(type_size as u8);
        }
        stream.read_bytes(&mut vector, count * type_size);
        EncodableValue::ByteList(vector)
    }

    fn write_vector<T>(&self, vector: Vec<T>, stream: &mut dyn ByteStreamWriter) {
        let count = vector.len();
        self.write_size(count, stream);
        if count == 0 {
            return;
        }
        let type_size = std::mem::size_of::<T>();
        if type_size > 1 {
            stream.write_alignment(type_size as u8);
        }
        let vector_ptr = vector.as_ptr() as *const u8;
        unsafe {
            stream.write_bytes(std::slice::from_raw_parts(vector_ptr, count * type_size), count * type_size);
        }
    }
}
