# APK delivery

- The user requires every delivered APK to be strictly smaller than 20,000,000 bytes (20 MB). Check the actual final file size before delivery.
- Use `tools/build_small_apk.ps1` for APK builds. It creates an ARM64 release, optimizes only build copies of profile images, verifies signing and size, and removes its temporary build folders.
- Keep original project images unchanged. Include all profile photos and UI icons in the APK.
- State that the delivered APK is for 64-bit ARM Android phones. Use a higher version code and the existing signing key for updates.
- Do not accumulate separate build or preview copies. Clean temporary packaging copies after preserving and verifying the final APK.
