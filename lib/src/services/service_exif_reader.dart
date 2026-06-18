// ============================================================
// lib/src/services/service_exif_reader.dart
// 纯 Dart JPEG EXIF 解析器（兜底，覆盖 Windows/macOS/Linux）
// native_exif 仅支持 iOS/Android，桌面平台需要自实现。
// 只解析项目需要的标签，避免过度工程。
// ============================================================
import 'dart:io';
import 'dart:typed_data';

/// 解析后的 EXIF 标签集合（与 native_exif 的字段名保持一致）
class ExifTags {
  final Map<String, String> attrs = {};
  final Map<String, String> exif = {}; // ExifIFD 子表
  final Map<String, String> gps = {}; // GPS IFD 子表
}

/// 解析 JPEG 的 EXIF 段。
/// 成功返回 ExifTags，失败（不是 JPEG / 没有 EXIF / 解析异常）返回 null。
Future<ExifTags?> readJpegExif(String filePath) async {
  try {
    final raf = await File(filePath).open();
    try {
      // 先看前 64KB，绝大多数 JPEG 的 EXIF 都在这
      final header = await raf.read(65536);
      return _parse(header);
    } finally {
      await raf.close();
    }
  } catch (_) {
    return null;
  }
}

ExifTags? _parse(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

  var i = 2;
  while (i < bytes.length - 1) {
    if (bytes[i] != 0xFF) return null;
    // 跳过填充 0xFF
    while (i < bytes.length && bytes[i] == 0xFF) {
      i++;
    }
    if (i >= bytes.length) return null;
    final marker = bytes[i];
    i++;

    // 0xD9 = EOI，结束
    if (marker == 0xD9) return null;
    // 0xDA = SOS，后面是图像数据，停止扫描
    if (marker == 0xDA) return null;
    // 没有长度字段的标记
    if (marker == 0xD0 ||
        marker == 0xD1 ||
        marker == 0xD2 ||
        marker == 0xD3 ||
        marker == 0xD4 ||
        marker == 0xD5 ||
        marker == 0xD6 ||
        marker == 0xD7 ||
        (marker >= 0xD8 && marker <= 0xDF)) {
      continue;
    }
    if (i + 1 >= bytes.length) return null;
    final segLen = (bytes[i] << 8) | bytes[i + 1];
    if (segLen < 2 || i + segLen > bytes.length) return null;
    final segEnd = i + segLen;

    if (marker == 0xE1) {
      // APP1 - 检查 "Exif\0\0" 签名
      if (i + 8 <= bytes.length &&
          bytes[i + 2] == 0x45 &&
          bytes[i + 3] == 0x78 &&
          bytes[i + 4] == 0x69 &&
          bytes[i + 5] == 0x66 &&
          bytes[i + 6] == 0x00 &&
          bytes[i + 7] == 0x00) {
        final tiffStart = i + 8;
        return _parseTiff(bytes, tiffStart, segEnd);
      }
    }
    i = segEnd;
  }
  return null;
}

ExifTags? _parseTiff(Uint8List bytes, int tiffStart, int tiffEnd) {
  if (tiffStart + 8 > tiffEnd) return null;
  // 字节序
  final isLE = bytes[tiffStart] == 0x49 && bytes[tiffStart + 1] == 0x49; // 'II'
  final isBE = bytes[tiffStart] == 0x4D && bytes[tiffStart + 1] == 0x4D; // 'MM'
  if (!isLE && !isBE) return null;
  int u16(int off) => isLE
      ? (bytes[off] | (bytes[off + 1] << 8))
      : ((bytes[off] << 8) | bytes[off + 1]);
  int u32(int off) => isLE
      ? (bytes[off] |
          (bytes[off + 1] << 8) |
          (bytes[off + 2] << 16) |
          (bytes[off + 3] << 24))
      : ((bytes[off] << 24) |
          (bytes[off + 1] << 16) |
          (bytes[off + 2] << 8) |
          bytes[off + 3]);

  // TIFF 头：II 0x002A ifd0Offset
  final magic = u16(tiffStart + 2);
  if (magic != 0x002A) return null;
  final ifd0Off = tiffStart + u32(tiffStart + 4);
  if (ifd0Off + 2 > tiffEnd) return null;

  final result = ExifTags();
  String? exifIfdOffRel;
  String? gpsIfdOffRel;

  // IFD0
  final ifd0Entries = u16(ifd0Off);
  for (int k = 0; k < ifd0Entries; k++) {
    final entryOff = ifd0Off + 2 + k * 12;
    if (entryOff + 12 > tiffEnd) break;
    final tag = u16(entryOff);
    final type = u16(entryOff + 2);
    final count = u32(entryOff + 4);

    if (tag == 0x8769) {
      // ExifIFD pointer
      exifIfdOffRel = (u32(entryOff + 8) + tiffStart).toString();
    } else if (tag == 0x8825) {
      // GPS IFD pointer
      gpsIfdOffRel = (u32(entryOff + 8) + tiffStart).toString();
    } else {
      final v =
          _readValue(bytes, tiffStart, tiffEnd, entryOff, type, count, isLE);
      if (v != null) {
        final name = _tagName(tag);
        if (name != null) result.attrs[name] = v;
      }
    }
  }

  // ExifIFD
  if (exifIfdOffRel != null) {
    final exifIfd = int.parse(exifIfdOffRel);
    if (exifIfd + 2 <= tiffEnd) {
      final n = u16(exifIfd);
      for (int k = 0; k < n; k++) {
        final entryOff = exifIfd + 2 + k * 12;
        if (entryOff + 12 > tiffEnd) break;
        final tag = u16(entryOff);
        final type = u16(entryOff + 2);
        final count = u32(entryOff + 4);
        final v =
            _readValue(bytes, tiffStart, tiffEnd, entryOff, type, count, isLE);
        if (v != null) {
          final name = _tagName(tag);
          if (name != null) result.exif[name] = v;
        }
      }
    }
  }

  // GPS IFD
  if (gpsIfdOffRel != null) {
    final gpsIfd = int.parse(gpsIfdOffRel);
    if (gpsIfd + 2 <= tiffEnd) {
      final n = u16(gpsIfd);
      for (int k = 0; k < n; k++) {
        final entryOff = gpsIfd + 2 + k * 12;
        if (entryOff + 12 > tiffEnd) break;
        final tag = u16(entryOff);
        final type = u16(entryOff + 2);
        final count = u32(entryOff + 4);
        final v =
            _readValue(bytes, tiffStart, tiffEnd, entryOff, type, count, isLE);
        if (v != null) {
          // GPS 标签名都加 "GPS" 前缀，跟 iOS native_exif 一致
          final name = _gpsTagName(tag);
          if (name != null) result.gps[name] = v;
        }
      }
    }
  }

  // 合并为扁平的 attr map（按 native_exif 行为）
  result.attrs.addAll(result.exif);
  result.attrs.addAll(result.gps);

  return result;
}

/// 读取一个 IFD entry 的值。
/// type: 1=BYTE 2=ASCII 3=SHORT 4=LONG 5=RATIONAL 7=UNDEFINED 9=SLONG 10=SRATIONAL
String? _readValue(
  Uint8List bytes,
  int tiffStart,
  int tiffEnd,
  int entryOff,
  int type,
  int count,
  bool isLE,
) {
  // 4 字节内联或偏移
  const valueBytes = 4;
  int totalSize;
  switch (type) {
    case 1:
    case 2:
    case 7:
      totalSize = count; // 1 byte each
      break;
    case 3:
      totalSize = count * 2;
      break;
    case 4:
    case 9:
      totalSize = count * 4;
      break;
    case 5:
    case 10:
      totalSize = count * 8;
      break;
    default:
      return null;
  }

  int dataStart;
  if (totalSize <= valueBytes) {
    dataStart = entryOff + 8;
  } else {
    final offset = isLE
        ? (bytes[entryOff + 8] |
            (bytes[entryOff + 9] << 8) |
            (bytes[entryOff + 10] << 16) |
            (bytes[entryOff + 11] << 24))
        : ((bytes[entryOff + 8] << 24) |
            (bytes[entryOff + 9] << 16) |
            (bytes[entryOff + 10] << 8) |
            bytes[entryOff + 11]);
    dataStart = tiffStart + offset;
  }
  if (dataStart < 0 || dataStart + totalSize > tiffEnd) return null;

  int u16at(int p) => isLE
      ? (bytes[p] | (bytes[p + 1] << 8))
      : ((bytes[p] << 8) | bytes[p + 1]);
  int u32at(int p) => isLE
      ? (bytes[p] |
          (bytes[p + 1] << 8) |
          (bytes[p + 2] << 16) |
          (bytes[p + 3] << 24))
      : ((bytes[p] << 24) |
          (bytes[p + 1] << 16) |
          (bytes[p + 2] << 8) |
          bytes[p + 3]);

  switch (type) {
    case 2: // ASCII
      // 以 \0 结尾
      var end = dataStart;
      while (end < dataStart + count && bytes[end] != 0) {
        end++;
      }
      return String.fromCharCodes(bytes.sublist(dataStart, end));
    case 3: // SHORT
      if (count == 1) return u16at(dataStart).toString();
      return List.generate(count, (k) => u16at(dataStart + k * 2).toString())
          .join(',');
    case 4: // LONG
      if (count == 1) return u32at(dataStart).toString();
      return List.generate(count, (k) => u32at(dataStart + k * 4).toString())
          .join(',');
    case 5: // RATIONAL (u32/u32) - GPS 坐标(3 个)、曝光时间(1 个)
      String one(int p) {
        final n = u32at(p);
        final d = u32at(p + 4);
        return d == 0 ? '0' : '$n/$d';
      }
      if (count == 1) return one(dataStart);
      return List.generate(count, (k) => one(dataStart + k * 8)).join(',');
    default:
      return null;
  }
}

/// IFD0 标签名（与 native_exif 在 Android 上用 androidx ExifInterface 时的 key 一致）
String? _tagName(int tag) {
  switch (tag) {
    case 0x010F:
      return 'Make';
    case 0x0110:
      return 'Model';
    case 0x0112:
      return 'Orientation';
    case 0x011A:
      return 'XResolution';
    case 0x011B:
      return 'YResolution';
    case 0x0128:
      return 'ResolutionUnit';
    case 0x0131:
      return 'Software';
    case 0x013B:
      return 'Artist';
    case 0x013E:
      return 'WhitePoint';
    case 0x013F:
      return 'PrimaryChromaticities';
    case 0x0211:
      return 'YCbCrCoefficients';
    case 0x0213:
      return 'YCbCrPositioning';
    case 0x0214:
      return 'ReferenceBlackWhite';
    case 0x8298:
      return 'Copyright';
    case 0x8769:
      return null; // ExifIFD pointer，由调用方特殊处理
    case 0x8825:
      return null; // GPS IFD pointer
    // ExifIFD
    case 0x829A:
      return 'ExposureTime';
    case 0x829D:
      return 'FNumber';
    case 0x8822:
      return 'ExposureProgram';
    case 0x8827:
      return 'ISOSpeedRatings';
    case 0x9000:
      return 'ExifVersion';
    case 0x9003:
      return 'DateTimeOriginal';
    case 0x9004:
      return 'DateTimeDigitized';
    case 0x9201:
      return 'ShutterSpeedValue';
    case 0x9202:
      return 'ApertureValue';
    case 0x9204:
      return 'ExposureBiasValue';
    case 0x9205:
      return 'MaxApertureValue';
    case 0x9207:
      return 'MeteringMode';
    case 0x9208:
      return 'LightSource';
    case 0x9209:
      return 'Flash';
    case 0x920A:
      return 'FocalLength';
    case 0x927C:
      return 'MakerNote';
    case 0x9286:
      return 'UserComment';
    case 0xA001:
      return 'ColorSpace';
    case 0xA002:
      return 'PixelXDimension';
    case 0xA003:
      return 'PixelYDimension';
    case 0xA20E:
      return 'FocalPlaneXResolution';
    case 0xA20F:
      return 'FocalPlaneYResolution';
    case 0xA210:
      return 'FocalPlaneResolutionUnit';
    case 0xA217:
      return 'SensingMethod';
    case 0xA300:
      return 'FileSource';
    case 0xA301:
      return 'SceneType';
    case 0xA401:
      return 'CustomRendered';
    case 0xA402:
      return 'ExposureMode';
    case 0xA403:
      return 'WhiteBalance';
    case 0xA404:
      return 'DigitalZoomRatio';
    case 0xA405:
      return 'FocalLengthIn35mmFilm';
    case 0xA406:
      return 'SceneCaptureType';
    case 0xA432:
      return 'LensSpecification';
    case 0xA433:
      return 'LensMake';
    case 0xA434:
      return 'LensModel';
    default:
      return null;
  }
}

/// GPS 标签名（与 native_exif iOS 的 key 一致）
String? _gpsTagName(int tag) {
  switch (tag) {
    case 0x0000:
      return 'GPSVersionID';
    case 0x0001:
      return 'GPSLatitudeRef';
    case 0x0002:
      return 'GPSLatitude';
    case 0x0003:
      return 'GPSLongitudeRef';
    case 0x0004:
      return 'GPSLongitude';
    case 0x0005:
      return 'GPSAltitudeRef';
    case 0x0006:
      return 'GPSAltitude';
    case 0x0007:
      return 'GPSTimeStamp';
    case 0x0009:
      return 'GPSStatus';
    case 0x000C:
      return 'GPSSpeedRef';
    case 0x000D:
      return 'GPSSpeed';
    case 0x0010:
      return 'GPSImgDirectionRef';
    case 0x0011:
      return 'GPSImgDirection';
    case 0x001D:
      return 'GPSDateStamp';
    case 0x001B:
      return 'GPSProcessingMethod';
    default:
      return null;
  }
}
