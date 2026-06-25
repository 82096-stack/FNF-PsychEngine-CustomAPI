# DLSS SDK Files

This directory contains NVIDIA DLSS (Deep Learning Super Sampling) SDK redistributables.

## Contents

- `include/` — NGX SDK headers (nvsdk_ngx.h, helpers, definitions)
- `lib/` — Runtime DLLs and import libraries

## DLL Files

| File | Purpose |
|------|---------|
| `nvngx_dlss.dll` | DLSS Super Sampling (upscaling) |
| `nvngx_dlssd.dll` | DLSS Ray Reconstruction (denoising) |
| `nvngx_dlssg.dll` | DLSS Frame Generation |

## Windows Linking

For Windows builds, the import library `nvsdk_ngx.lib` is needed to link against `nvngx_dlss.dll`.
This can be generated from the DLL using Visual Studio's `lib.exe`:
```
lib /def:nvngx_dlss.def /out:nvsdk_ngx.lib /machine:x64
```
Or obtained from the NVIDIA NGX SDK developer package.

## Requirements

- NVIDIA RTX 20-series GPU or newer (Turing architecture or later)
- Latest NVIDIA Game Ready Driver or Studio Driver
- Windows 10/11 (64-bit)

## License

These files are redistributables from the NVIDIA NGX SDK. Refer to NVIDIA's NGX SDK EULA for distribution terms.
