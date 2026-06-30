import pathlib

f = pathlib.Path(r'E:\flutter\desk-pic-view\assets\USER_MANUAL.md')
content = f.read_text(encoding='utf-8')

# 替换 12.5 节
old = '''### 12.5 国内网络特殊处理

Flutter SDK 从 Google 服务器下载，国内网络可能需要翻墙。

**若下载失败**，脚本会提示手动下载，也可使用 Flutter 中文社区镜像：

- 手动下载地址：https://docs.flutter.dev/get-started/install/windows
- 国内镜像站：https://flutter.cn/docs/get-started/install/windows
- 手动配置镜像环境变量（脚本已自动配置，以下为手动方式）：

```powershell
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL",     "https://pub.flutter-io.cn", "User")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
```'''

new = '''### 12.5 国内网络加速（内置）

脚本**默认启用国内镜像加速**（`-UseMirror $true`），无需手动配置。若下载仍慢，可检查网络连接。

内置镜像对照表：

| 下载项 | 国内镜像（默认） | 官方源（`-UseMirror $false`） |
| --- | --- | --- |
| Flutter SDK | `storage.flutter-io.cn` | `storage.googleapis.com` |
| Git for Windows | `ghproxy.com`（GitHub 代理） | `github.com` |
| pub.dev 依赖 | `pub.flutter-io.cn` | `pub.dev` |

`pub.flutter-io.cn` 镜像在第 4 步自动配置为用户级环境变量（`PUB_HOSTED_URL`），永久生效。

若需关闭镜像加速，运行脚本时加参数：

```powershell
.\setup_flutter_env.ps1 -UseMirror $false
```'''

if old in content:
    content = content.replace(old, new)
    print('OK - replaced section 12.5')
else:
    print('WARN - section 12.5 not found, dumping surrounding text for debug:')
    idx = content.find('### 12.5')
    if idx >= 0:
        print(repr(content[idx:idx+200]))
    else:
        print('Section 12.5 header not found at all')

# 写回文件（UTF-8 without BOM for USER_MANUAL.md）
f.write_text(content, encoding='utf-8')
print('OK - file saved')
