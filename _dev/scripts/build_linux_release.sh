#!/usr/bin/env bash
# ============================================================
# build_linux_release.sh - PixelVault Linux 一键打包脚本
# ============================================================
#
# 用法（在项目根目录执行）：
#   chmod +x build_linux_release.sh
#   ./build_linux_release.sh [选项]
#
# 选项:
#   -v, --version VERSION     指定版本号（默认从 pubspec.yaml 读取）
#   -o, --output DIR          输出目录（默认 ./dist）
#   -s, --skip-build          跳过 flutter build，复用已有 bundle
#   -p, --skip-appimage       跳过 AppImage 生成（仅输出 raw bundle）
#   -f, --flutter PATH        指定 flutter 可执行路径（默认 flutter）
#   -d, --linuxdeploy PATH    指定 linuxdeploy 可执行路径
#                             默认自动下载到 ./dist/.tools/linuxdeploy
#   -h, --help                显示帮助
#
# 前置环境（构建机器）：
#   1. Flutter >= 3.16，启用了 Linux 桌面支持
#      $ flutter config --enable-linux-desktop
#   2. 编译工具链：gcc / g++ / cmake / ninja / pkg-config
#      $ sudo apt install build-essential cmake ninja-build pkg-config \
#                         libgtk-3-dev liblzma-dev libstdc++-12-dev
#   3. libmpv 开发包（用于视频播放，media_kit 需要）
#      $ sudo apt install libmpv-dev mpv
#   4. （可选）libfuse2 — AppImage 运行需要
#      $ sudo apt install libfuse2
# ============================================================

set -euo pipefail

# ────────── 颜色 ──────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[1;30m'
NC='\033[0m'

# ────────── 默认值 ──────────
VERSION=""
OUTPUT_DIR="dist"
SKIP_BUILD=false
SKIP_APPIMAGE=false
FLUTTER_BIN="flutter"
LINUXDEPLOY_BIN=""

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_DIR="build/linux/x64/release/bundle"

# ────────── 工具函数 ──────────

section() {
    echo ""
    printf "${GRAY}============================================================${NC}\n"
    printf "${CYAN}▶ $1${NC}\n"
    printf "${GRAY}============================================================${NC}\n"
}

ok()   { printf "  ${GREEN}✔${NC}  %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${NC}  %s\n" "$1"; }
err()  { printf "  ${RED}✖${NC}  %s\n" "$1"; }

read_pubspec_version() {
    local f="$PROJECT_ROOT/pubspec.yaml"
    [ -f "$f" ] || { err "未找到 pubspec.yaml"; exit 1; }
    grep -Po '(?<=^version:\s)[0-9]+\.[0-9]+\.[0-9]+' "$f" || {
        err "无法从 pubspec.yaml 解析 version"; exit 1
    }
}

human_size() {
    local b=$1
    if   [ "$b" -ge 1073741824 ]; then echo "$(echo "scale=2; $b/1073741824" | bc) GB"
    elif [ "$b" -ge 1048576 ];    then echo "$(echo "scale=2; $b/1048576"    | bc) MB"
    elif [ "$b" -ge 1024 ];       then echo "$(echo "scale=2; $b/1024"       | bc) KB"
    else echo "${b} B"
    fi
}

usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  -v, --version VERSION     指定版本号（默认从 pubspec.yaml 读取）
  -o, --output DIR          输出目录（默认 ./dist）
  -s, --skip-build          跳过 flutter build，复用已有 bundle
  -p, --skip-appimage       跳过 AppImage 生成（仅输出 raw bundle）
  -f, --flutter PATH        指定 flutter 可执行路径
  -d, --linuxdeploy PATH    指定 linuxdeploy 可执行路径
  -h, --help                显示此帮助
EOF
    exit 0
}

# ────────── 参数解析 ──────────

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version)        VERSION="$2";        shift 2 ;;
        -o|--output)         OUTPUT_DIR="$2";     shift 2 ;;
        -s|--skip-build)     SKIP_BUILD=true;     shift   ;;
        -p|--skip-appimage)  SKIP_APPIMAGE=true;  shift   ;;
        -f|--flutter)        FLUTTER_BIN="$2";    shift 2 ;;
        -d|--linuxdeploy)    LINUXDEPLOY_BIN="$2"; shift 2 ;;
        -h|--help)           usage                ;;
        *) echo "未知参数: $1"; usage ;;
    esac
done

# ────────── 1. 预检查 ──────────

section "环境检查"

# Flutter
command -v "$FLUTTER_BIN" &>/dev/null || { err "未找到 flutter"; exit 1; }
ok "Flutter 路径: $(command -v "$FLUTTER_BIN")"
ok "Flutter 版本: $("$FLUTTER_BIN" --version 2>&1 | head -1)"

# Linux 桌面
"$FLUTTER_BIN" config 2>&1 | grep -q "enable-linux-desktop:\s*true" || {
    warn "正在启用 Linux 桌面支持..."
    "$FLUTTER_BIN" config --enable-linux-desktop
    ok "已启用"
}

# 版本号
[ -n "$VERSION" ] || VERSION=$(read_pubspec_version)
ok "版本号: $VERSION"

# 构建工具
for t in cmake ninja pkg-config gcc g++; do
    command -v "$t" &>/dev/null || { err "缺少: $t"; exit 1; }
done
ok "构建工具链就绪"

# libmpv（media_kit 必需）
pkg-config --exists mpv 2>/dev/null || {
    warn "未检测到 libmpv，尝试自动安装..."
    if command -v sudo &>/dev/null && command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq libmpv-dev mpv
        ok "libmpv-dev + mpv 已安装"
    else
        err "请手动安装: sudo apt install libmpv-dev mpv"
        exit 1
    fi
}
ok "libmpv 就绪"

# ────────── 2. 输出目录 ──────────

section "准备输出目录"
mkdir -p "$OUTPUT_DIR"
OUTPUT_ABS_DIR="$(cd "$OUTPUT_DIR" && pwd)"
ok "输出目录: $OUTPUT_ABS_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BASE_NAME="PixelVault-${VERSION}-linux-x64"

# ────────── 3. pub get ──────────

section "1/4  拉取依赖"
cd "$PROJECT_ROOT"
"$FLUTTER_BIN" pub get
ok "依赖已更新"

# ────────── 4. build ──────────

if [ "$SKIP_BUILD" = false ]; then
    section "2/4  编译 Linux Release"
    [ -d "build/linux" ] && rm -rf build/linux
    BUILD_START=$(date +%s)
    "$FLUTTER_BIN" build linux --release
    BUILD_END=$(date +%s)
    [ -f "$BUNDLE_DIR/pixelvault" ] || { err "构建产物未找到"; exit 1; }
    ok "构建完成，耗时 $((BUILD_END - BUILD_START))s"
else
    section "2/4  编译 Linux Release（跳过）"
    [ -f "$BUNDLE_DIR/pixelvault" ] || {
        err "未找到 $BUNDLE_DIR/pixelvault，请先去掉 --skip-build 执行一次完整构建"
        exit 1
    }
    ok "复用既有 bundle"
fi

BUNDLE_ABS_DIR="$(cd "$BUNDLE_DIR" && pwd)"
ok "主程序: $BUNDLE_ABS_DIR/pixelvault"

# ────────── 5. 拷贝文档 ──────────

section "3/4  拷贝使用手册"
MANUAL_SRC="$PROJECT_ROOT/assets/USER_MANUAL.md"
if [ -f "$MANUAL_SRC" ]; then
    cp "$MANUAL_SRC" "$BUNDLE_ABS_DIR/USER_MANUAL.md"
    ok "已复制: $BUNDLE_ABS_DIR/USER_MANUAL.md"
else
    warn "未找到 USER_MANUAL.md，跳过"
fi

# ────────── 6. AppImage ──────────

if [ "$SKIP_APPIMAGE" = false ]; then
    section "4/4  生成 AppImage"

    # ── 6a) 准备 linuxdeploy ──
    TOOLS_DIR="$OUTPUT_ABS_DIR/.tools"
    mkdir -p "$TOOLS_DIR"

    if [ -n "$LINUXDEPLOY_BIN" ]; then
        LINUXDEPLOY="$LINUXDEPLOY_BIN"
    else
        LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
        if [ ! -f "$LINUXDEPLOY" ]; then
            URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
            if command -v wget &>/dev/null; then
                wget -q --show-progress "$URL" -O "$LINUXDEPLOY"
            elif command -v curl &>/dev/null; then
                curl -L "$URL" -o "$LINUXDEPLOY"
            else
                err "请安装 wget 或 curl"; exit 1
            fi
            ok "linuxdeploy 已下载"
        fi

        PLUGIN="$TOOLS_DIR/linuxdeploy-plugin-appimage-x86_64.AppImage"
        if [ ! -f "$PLUGIN" ]; then
            URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage"
            if command -v wget &>/dev/null; then
                wget -q --show-progress "$URL" -O "$PLUGIN"
            else
                curl -L "$URL" -o "$PLUGIN"
            fi
            ok "linuxdeploy-plugin-appimage 已下载"
        fi
    fi

    chmod +x "$LINUXDEPLOY" "$PLUGIN" 2>/dev/null || true

    # ── 6b) 构建 AppDir ──
    # 策略：用 Flutter bundle 原始结构作为 AppDir
    # 这不是标准 FHS 布局，但 linuxdeploy 可以处理：
    # 只要指定 --executable 路径，它会自动扫描所有 .so 并复制到 usr/lib/
    APPDIR="$OUTPUT_ABS_DIR/${BASE_NAME}.AppDir"
    [ -d "$APPDIR" ] && rm -rf "$APPDIR"

    # 把整个 Flutter bundle 作为 AppDir 根
    cp -r "$BUNDLE_ABS_DIR" "$APPDIR"

    # .desktop 入口
    cat > "$APPDIR/pixelvault.desktop" << DESKTOP
[Desktop Entry]
Name=PixelVault
Comment=图片视频浏览器 - 标签归档、EXIF筛选、仪表盘
Exec=pixelvault
Icon=pixelvault
Terminal=false
Type=Application
Categories=Graphics;Viewer;
DESKTOP

    # SVG 图标（128×128，紫色渐变 "P" 图标）
    cat > "$APPDIR/pixelvault.svg" << 'ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#6366f1"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="24" fill="url(#g)"/>
  <circle cx="40" cy="44" r="12" fill="#fff" opacity=".6"/>
  <path d="M26 80 L52 54 L68 70 L84 50 L104 76 L104 86 L26 86Z" fill="#fff" opacity=".5"/>
  <polygon points="80,40 90,34 86,46" fill="#fff" opacity=".7"/>
</svg>
ICON

    # ── 6c) 运行 linuxdeploy ──
    export LINUXDEPLOY_NO_STRIP=1

    # 绕过 FUSE 限制（Docker/CI 环境）
    if ! command -v fusermount &>/dev/null && ! command -v fusermount3 &>/dev/null; then
        warn "无 FUSE，使用 extract-and-run 模式"
        # linuxdeploy 会检测到无 FUSE 时自动 fallback
    fi

    ok "正在扫描并打包 .so 依赖..."

    APPIMAGE_START=$(date +%s)

    # 第一步：扫描二进制依赖并复制 .so
    "$LINUXDEPLOY" \
        --appdir "$APPDIR" \
        --executable "$APPDIR/pixelvault" \
        --desktop-file "$APPDIR/pixelvault.desktop" \
        --icon-file "$APPDIR/pixelvault.svg" \
        ${GPG_BIN:+--gpg "$GPG_BIN"} \
        2>&1 | while IFS= read -r line; do
            case "$line" in
                *"WARNING:"*) warn "$line" ;;
                *"ERROR:"*|*"error:"*) err "$line" ;;
                *"Deploying"*) [[ "$line" == *".so"* ]] && printf "    %s\n" "$line" ;;
            esac
        done || warn "linuxdeploy 有非致命告警（通常可忽略）"

    # 第二步：生成 AppImage
    export OUTPUT="${BASE_NAME}.AppImage"
    chmod +x "$PLUGIN" 2>/dev/null || true
    ok "正在打包为 AppImage..."

    "$PLUGIN" --appdir "$APPDIR" 2>&1 | while IFS= read -r line; do
        case "$line" in
            *"WARNING:"*) warn "$line" ;;
            *"ERROR:"*)   err "$line" ;;
        esac
    done || warn "AppImage 打包有非致命告警"

    APPIMAGE_END=$(date +%s)
    APPIMAGE_ELAPSED=$((APPIMAGE_END - APPIMAGE_START))

    # 清理 AppDir
    rm -rf "$APPDIR" 2>/dev/null || true

    # ── 6d) 查找产物 ──
    FINAL_APPIMAGE=""
    # linuxdeploy 有时把 AppImage 放在 OUTPUT_DIR 或 APPDIR 的同级目录
    for cand in "$OUTPUT_ABS_DIR/$BASE_NAME.AppImage" "$OUTPUT_ABS_DIR"/*.AppImage "$OUTPUT_ABS_DIR"/../*.AppImage; do
        [ -f "$cand" ] && { FINAL_APPIMAGE="$cand"; break; }
    done

    if [ -n "$FINAL_APPIMAGE" ]; then
        SIZE=$(stat -c%s "$FINAL_APPIMAGE" 2>/dev/null || stat -f%z "$FINAL_APPIMAGE" 2>/dev/null)
        ok "AppImage 生成完成（${APPIMAGE_ELAPSED}s）:"
        ok "  $(basename "$FINAL_APPIMAGE") ($(human_size "$SIZE"))"
    else
        warn "AppImage 未成功生成，回退到 raw bundle 压缩包"
        RAW="$OUTPUT_ABS_DIR/$BASE_NAME"
        cp -r "$BUNDLE_ABS_DIR" "$RAW"
        ok "已输出 raw bundle: $RAW/"
    fi
else
    section "4/4  生成 AppImage（跳过）"
    RAW="$OUTPUT_ABS_DIR/$BASE_NAME"
    cp -r "$BUNDLE_ABS_DIR" "$RAW"
    ok "已输出 raw bundle: $RAW/"
fi

# ────────── 7. 压缩 + 校验和 ──────────

section "打包与校验"

cd "$OUTPUT_ABS_DIR"

# 对 raw bundle（如果有）压缩 + 校验
for d in "$BASE_NAME"; do
    [ -d "$d" ] || continue
    TARBALL="${d}.tar.gz"
    tar czf "$TARBALL" "$d"
    sha256sum "$TARBALL" > "${TARBALL}.sha256.txt"
    TAR_SIZE=$(stat -c%s "$TARBALL" 2>/dev/null || stat -f%z "$TARBALL" 2>/dev/null)
    ok "已压缩: $TARBALL ($(human_size "$TAR_SIZE"))"
    rm -rf "$d"
done

# 对 AppImage 生成校验和
for f in *.AppImage; do
    [ -f "$f" ] || continue
    sha256sum "$f" > "${f}.sha256.txt"
    ok "校验和: ${f}.sha256.txt"
done

cd "$PROJECT_ROOT"

# ────────── 8. 汇总 ──────────

section "完成 ✅"
echo ""
printf "  ${GREEN}版本:${NC}     %s\n" "$VERSION"
printf "  ${GREEN}源码目录:${NC} $PROJECT_ROOT\n"
printf "  ${GREEN}Bundle:${NC}   $BUNDLE_ABS_DIR\n"
printf "  ${GREEN}输出目录:${NC} $OUTPUT_ABS_DIR\n"
echo ""

printf "${CYAN}📦 输出文件:${NC}\n"
ls -lh "$OUTPUT_ABS_DIR"/*.{AppImage,tar.gz,sha256.txt} 2>/dev/null | \
    awk '{ printf "    %s %s %s\n", $5, $6, $NF }'

echo ""
printf "${CYAN}🚀 下一步:${NC}\n"
printf "  ${GRAY}  • 本地试运行:${NC} $BUNDLE_ABS_DIR/pixelvault\n"

AP=$(find "$OUTPUT_ABS_DIR" -name "*.AppImage" -print -quit 2>/dev/null || true)
[ -n "$AP" ] && printf "  ${GRAY}  • 分发 AppImage:${NC} $AP\n"

TAR=$(find "$OUTPUT_ABS_DIR" -name "*.tar.gz" -print -quit 2>/dev/null || true)
[ -n "$TAR" ] && printf "  ${GRAY}  • 分发绿色版 tar.gz:${NC} $TAR\n"

echo ""

# libmpv 提醒
printf "${GRAY}分发提醒:${NC}\n"
if [ -n "$AP" ]; then
    printf "  AppImage 已内含 libmpv + FFmpeg 所有依赖，用户无需额外安装\n"
else
    printf "  用户运行 raw bundle 前需安装: sudo apt install libmpv-dev mpv\n"
fi
echo ""
