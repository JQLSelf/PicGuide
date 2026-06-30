// ============================================================
// native/src/exif.rs
// JPEG EXIF 解析 — kamadak-exif crate (原生 Rust)
// 替换 587 行手写 Dart 二进制解析器
// ============================================================
use exif::{Exif, In, Reader, Tag};
use std::fs::File;
use std::io::BufReader;

/// 解析 JPEG EXIF 元数据
pub fn parse_exif(path: &str) -> Option<ExifData> {
    let file = File::open(path).ok()?;
    let mut reader = BufReader::new(file);
    let exif = Reader::new().read_from_container(&mut reader).ok()?;

    // 辅助：按 tag 取字段的字符串值
    fn get(exif: &Exif, tag: Tag) -> Option<String> {
        exif.get_field(tag, In::PRIMARY)
            .map(|f| f.display_value().to_string())
    }

    let lat = parse_gps(&exif, Tag::GPSLatitude, Tag::GPSLatitudeRef);
    let lng = parse_gps(&exif, Tag::GPSLongitude, Tag::GPSLongitudeRef);

    Some(ExifData {
        date_taken: get(&exif, Tag::DateTimeOriginal),
        make: get(&exif, Tag::Make),
        model: get(&exif, Tag::Model),
        iso: get(&exif, Tag::PhotographicSensitivity)
            .or_else(|| get(&exif, Tag::ISOSpeed)),
        f_number: get(&exif, Tag::FNumber),
        exposure: get(&exif, Tag::ExposureTime),
        focal: get(&exif, Tag::FocalLength),
        lat,
        lng,
        image_width: get(&exif, Tag::ImageWidth).and_then(|s| s.parse().ok()),
        image_height: get(&exif, Tag::ImageLength).and_then(|s| s.parse().ok()),
        orientation: get(&exif, Tag::Orientation),
    })
}

/// 解析 GPS 坐标字符串为十进制浮点数
fn parse_gps(exif: &Exif, coord_tag: Tag, ref_tag: Tag) -> Option<f64> {
    let coord = exif.get_field(coord_tag, In::PRIMARY)?;
    let coord_str = coord.display_value().to_string();
    let parts: Vec<&str> = coord_str.split(',').collect();
    if parts.len() != 3 {
        return None;
    }

    fn parse_frac(s: &str) -> Option<f64> {
        let parts: Vec<&str> = s.split('/').collect();
        match parts.len() {
            2 => Some(parts[0].trim().parse::<f64>().ok()? / parts[1].trim().parse::<f64>().ok()?),
            1 => parts[0].trim().parse::<f64>().ok(),
            _ => None,
        }
    }

    let deg = parse_frac(parts[0])?;
    let min = parse_frac(parts[1])?;
    let sec = parse_frac(parts[2])?;
    let mut value = deg + min / 60.0 + sec / 3600.0;

    let ref_val = exif
        .get_field(ref_tag, In::PRIMARY)
        .map(|f| f.display_value().to_string());
    if ref_val.as_deref() == Some("S") || ref_val.as_deref() == Some("W") {
        value = -value;
    }
    Some(value)
}

/// EXIF 元数据
pub struct ExifData {
    pub date_taken: Option<String>,
    pub make: Option<String>,
    pub model: Option<String>,
    pub iso: Option<String>,
    pub f_number: Option<String>,
    pub exposure: Option<String>,
    pub focal: Option<String>,
    pub lat: Option<f64>,
    pub lng: Option<f64>,
    pub image_width: Option<i32>,
    pub image_height: Option<i32>,
    pub orientation: Option<String>,
}
