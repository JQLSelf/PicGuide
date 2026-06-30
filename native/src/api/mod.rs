// ============================================================
// native/src/api/mod.rs
// FFI 导出函数 — flutter_rust_bridge 从此模块生成 Dart 绑定
// ============================================================

use crate::batch;
use crate::decoder;
use crate::hasher;

/// 批量处理文件（推荐）：Dart 传路径列表，Rust rayon 并行计算
#[flutter_rust_bridge::frb]
pub fn process_file_batch(paths: Vec<String>) -> Vec<batch::FileMeta> {
    batch::process_batch(&paths)
}

/// 生成缩略图，返回 JPEG 字节数组
#[flutter_rust_bridge::frb]
pub fn make_thumbnail(
    path: String,
    max_w: u32,
    max_h: u32,
    quality: u8,
) -> Option<decoder::ThumbnailResult> {
    decoder::make_thumbnail(&path, max_w, max_h, quality)
}

/// 单文件 MD5（兜底用，批量场景用 process_file_batch）
#[flutter_rust_bridge::frb]
pub fn compute_md5(path: String) -> Option<String> {
    hasher::file_md5(&path)
}

/// 原生库版本信息
#[flutter_rust_bridge::frb]
pub fn native_version() -> String {
    format!("native_media v{}", env!("CARGO_PKG_VERSION"))
}
