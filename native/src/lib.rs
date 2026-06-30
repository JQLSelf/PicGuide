mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// ============================================================
// native/src/lib.rs
// Rust 原生媒体处理库
//
// 模块划分：
//   api    — FFI 导出函数（flutter_rust_bridge 生成 Dart 绑定）
//   batch  — rayon 并行批量处理
//   decoder— libjpeg-turbo 缩略图
//   exif   — kamadak-exif EXIF 解析
//   hasher — MD5 流式哈希
// ============================================================

pub mod api;
pub mod batch;
pub mod decoder;
pub mod exif;
pub mod hasher;
