# Vds-Pro — VideoStar Pro Unlock 🔓

> Tự động unlock toàn bộ tính năng Pro/VIP của VideoStar 15.2.3

[![Build Pro](https://github.com/tp307228-droid/Vds-Pro/actions/workflows/build-pro.yml/badge.svg)](https://github.com/tp307228-droid/Vds-Pro/actions)
[![Release](https://img.shields.io/github/v/release/tp307228-droid/Vds-Pro?label=Download)](https://github.com/tp307228-droid/Vds-Pro/releases/latest)

---

## Đã Mở Khóa

- ✅ Toàn bộ hiệu ứng Pro & VIP
- ✅ Xuất video không giới hạn
- ✅ Tất cả preset & templates Premium
- ✅ Không watermark
- ✅ QR effects độc quyền

---

## Cách Dùng

### 1. Tải IPA Pro
👉 [**Releases**](https://github.com/tp307228-droid/Vds-Pro/releases/latest) → `VideoStar-Pro.ipa`

### 2. Cài đặt
- **TrollStore** (khuyến nghị)
- **AltStore** / **Sideloadly**

### 3. Mở ra dùng thôi
Không cần key, không cần đăng nhập!

---

## Muốn Có FallVds Tool?

Bản này chỉ có **Pro Unlock**.

Nếu bạn muốn **Pro + FallVds Tool** (Chạm Thay Media, Nhập QR, Hide Stream):
👉 [**VideoStar-Mod**](https://github.com/tp307228-droid/VideoStar-Mod)

---

## Cấu Trúc Source

```
pro/
├── Makefile
├── control
├── VdsPro/
│   └── VdsProUnlock.x    # Hook IAP, NSUserDefaults, subscription classes
└── .github/workflows/
    └── build-pro.yml     # GitHub Actions: build dylib + inject IPA
```

---

## Quy Trình Build (GitHub Actions)

```
Vds-Pro repo
   │
   ├── build-pro.yml chạy khi push
   │
   ├── 1. Build VdsProUnlock.dylib (Theos)
   ├── 2. Lấy base IPA (VideoStar 15.2.3)
   ├── 3. inject_dylib bỏ VdsProUnlock.dylib vào
   ├── 4. Repack → VideoStar-Pro.ipa
   └── 5. Publish Release
         │
         └── VideoStar-Mod repo pull VideoStar-Pro.ipa
             rồi inject thêm FallVdsTool.dylib
             → VideoStar-Mod-FallVds.ipa
```

---

## Discord

[![Discord](https://img.shields.io/badge/discord.gg%2Fswaggang-5865F2?logo=discord&logoColor=white)](https://discord.gg/swaggang)

---

> Made with ❤️ by **FallVds Team**
