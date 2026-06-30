// ============================================================
// native/src/batch.rs
// 批量并行处理 — rayon work-stealing 线程池
//
// par_iter() 自动管理线程数（默认 = CPU 核心数），
// 使用 work-stealing 调度确保负载均衡。
// 如需限制并发（磁盘 I/O 瓶颈时）：
//   rayon::ThreadPoolBuilder::new().num_threads(4).build_global().unwrap();
// ============================================================
use rayon::prelude::*;
use std::fs;

use crate::hasher;
use crate::exif;

/// 并行处理一批文件：每条线程内 MD5 + EXIF + stat 串行，线程间全并行
pub fn process_batch(paths: &[String]) -> Vec<FileMeta> {
    paths
        .par_iter()
        .map(|p| {
            let (size, modified) = file_stat(p);
            let md5 = hasher::file_md5(p);
            let exif = exif::parse_exif(p);
            FileMeta {
                file_path: p.clone(),
                md5,
                file_size: size,
                file_modified_secs: modified,
                exif,
            }
        })
        .collect()
}

/// 获取文件大小和修改时间
fn file_stat(path: &str) -> (u64, i64) {
    fs::metadata(path)
        .map(|m| {
            let modified = m
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            (m.len(), modified)
        })
        .unwrap_or((0, 0))
}

/// 单文件处理结果（供 FFI 导出）
pub struct FileMeta {
    pub file_path: String,
    pub md5: Option<String>,
    pub file_size: u64,
    pub file_modified_secs: i64,
    pub exif: Option<exif::ExifData>,
}
