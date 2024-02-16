// use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
// use serde::Serializer;
//
// pub struct StandardSerdeSerializer;
//
// impl Serializer for StandardSerdeSerializer {
//     type Ok = EncodableValue;
//     type Error = std::fmt::Error;
//
//     type SerializeSeq = Self;
//     type SerializeTuple = Self;
//     type SerializeTupleStruct = Self;
//     type SerializeTupleVariant = Self;
//     type SerializeMap = Self;
//     type SerializeStruct = Self;
//     type SerializeStructVariant = Self;
//
//     fn serialize_bool(self, v: bool) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Bool(v))
//     }
//
//     fn serialize_i8(self, v: i8) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int32(v as i32))
//     }
//
//     fn serialize_i16(self, v: i16) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int32(v as i32))
//     }
//
//     fn serialize_i32(self, v: i32) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int32(v))
//     }
//
//     fn serialize_i64(self, v: i64) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int64(v))
//     }
//
//     fn serialize_u8(self, v: u8) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int32(v as i32))
//     }
//
//     fn serialize_u16(self, v: u16) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int32(v as i32))
//     }
//
//     fn serialize_u32(self, v: u32) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Int64(v as i64))
//     }
//
//     fn serialize_u64(self, v: u64) -> Result<Self::Ok, Self::Error> {
//         // May panic if the value is too large.
//         Ok(EncodableValue::Int64(v as i64))
//     }
//
//     fn serialize_f32(self, v: f32) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Double(v as f64))
//     }
//
//     fn serialize_f64(self, v: f64) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Double(v))
//     }
//
//     fn serialize_char(self, v: char) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::String(v.to_string()))
//     }
//
//     fn serialize_str(self, v: &str) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::String(v.to_string()))
//     }
//
//     fn serialize_bytes(self, v: &[u8]) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::ByteList(v.to_vec()))
//     }
//
//     fn serialize_none(self) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Null)
//     }
//
//     fn serialize_some<T: ?Sized>(self, value: &T) -> Result<Self::Ok, Self::Error>
//     where
//         T: serde::Serialize,
//     {
//         value.serialize(self)
//     }
//
//     fn serialize_unit(self) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Null)
//     }
//
//     fn serialize_unit_struct(self, _name: &'static str) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Null)
//     }
//
//     fn serialize_unit_variant(
//         self,
//         _name: &'static str,
//         _variant_index: u32,
//         _variant: &'static str,
//     ) -> Result<Self::Ok, Self::Error> {
//         Err(Default::default())
//     }
//
//     fn serialize_newtype_struct<T: ?Sized>(
//         self,
//         _name: &'static str,
//         value: &T,
//     ) -> Result<Self::Ok, Self::Error>
//     where
//         T: serde::Serialize,
//     {
//         value.serialize(self)
//     }
//
//     fn serialize_newtype_variant<T: ?Sized>(
//         self,
//         name: &'static str,
//         _variant_index: u32,
//         variant: &'static str,
//         value: &T,
//     ) -> Result<Self::Ok, Self::Error>
//     where
//         T: serde::Serialize,
//     {
//         Ok(EncodableValue::Map(vec![
//             (
//                 EncodableValue::String(name.to_string()),
//                 EncodableValue::String(variant.to_string()),
//             ),
//             (
//                 EncodableValue::String("value".to_string()),
//                 value.serialize(self)?,
//             ),
//         ]))
//     }
//
//     fn serialize_seq(self, _len: Option<usize>) -> Result<Self::SerializeSeq, Self::Error> {
//         Ok(self)
//     }
//
//     fn serialize_tuple(self, _len: usize) -> Result<Self::SerializeTuple, Self::Error> {
//         Err(Default::default())
//     }
//
//     fn serialize_tuple_struct(
//         self,
//         _name: &'static str,
//         _len: usize,
//     ) -> Result<Self::SerializeTupleStruct, Self::Error> {
//         Err(Default::default())
//     }
//
//     fn serialize_tuple_variant(
//         self,
//         _name: &'static str,
//         _variant_index: u32,
//         _variant: &'static str,
//         _len: usize,
//     ) -> Result<Self::SerializeTupleVariant, Self::Error> {
//         Err(Default::default())
//     }
//
//     fn serialize_map(self, _len: Option<usize>) -> Result<Self::SerializeMap, Self::Error> {
//         Ok(self)
//     }
//
//     fn serialize_struct(
//         self,
//         _name: &'static str,
//         _len: usize,
//     ) -> Result<Self::SerializeStruct, Self::Error> {
//         Ok(self)
//     }
//
//     fn serialize_struct_variant(
//         self,
//         _name: &'static str,
//         _variant_index: u32,
//         _variant: &'static str,
//         _len: usize,
//     ) -> Result<Self::SerializeStructVariant, Self::Error> {
//         Ok(self)
//     }
// }
//
// impl serde::ser::SerializeSeq for StandardSerdeSerializer {
//     type Ok = EncodableValue;
//     type Error = std::fmt::Error;
//
//     fn serialize_element<T: ?Sized>(&mut self, value: &T) -> Result<(), Self::Error>
//     where
//         T: serde::Serialize,
//     {
//         value.serialize(self)?;
//         Ok(())
//     }
//
//     fn end(self) -> Result<Self::Ok, Self::Error> {
//         Ok(EncodableValue::Null)
//     }
// }
