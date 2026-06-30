// ============================================================
// native/src/hasher.rs
// MD5 哈希 — 流式 64KB buffer，全文件从不全量加载
// ============================================================
use std::fs::File;
use std::io::Read;
use md5::{Digest, Md5};

/// 计算文件 MD5（流式读取，64KB buffer）
pub fn file_md5(path: &str) -> Option<String> {
    let mut file = File::open(path).ok()?;
    let mut hasher = Md5::new();
    let mut buf = [0u8; 65536]; // 64KB
    loop {
        let n = file.read(&mut buf).ok()?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Some(format!("{:x}", hasher.finalize()))
}
