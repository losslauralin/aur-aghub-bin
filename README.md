# aghub-bin (AUR)

> 📦 **Unofficial** AUR package for [aghub](https://github.com/AkaraChen/aghub) — One hub for every AI coding agent.

This repository hosts the `PKGBUILD` and CI workflow for automatically publishing the upstream release to the Arch User Repository. The `aghub` project and its trademarks belong entirely to the original developers.

## 🚀 Installation

Available in the [AUR](https://aur.archlinux.org/packages/aghub-bin). Install it using your preferred AUR helper:

```bash
paru -S aghub-bin
# or
yay -S aghub-bin
```

## 🛠️ Troubleshooting (NVIDIA + Wayland Users)

On NVIDIA proprietary drivers under Wayland, WebKitGTK can crash when its DMA-BUF renderer negotiates the `linux-drm-syncobj-v1` explicit sync protocol with the driver. The package desktop entry sets `__NV_DISABLE_EXPLICIT_SYNC=1` so NVIDIA falls back to implicit sync while keeping hardware acceleration enabled.

* **Launching via App Icon:** The included `.desktop` file already applies the NVIDIA Wayland compatibility variable.

* **Launching via Terminal:** If you run the GUI directly from your terminal, apply the same variable manually:

  ```bash
  __NV_DISABLE_EXPLICIT_SYNC=1 aghub
  ```

`GDK_BACKEND=x11 WEBKIT_DISABLE_DMABUF_RENDERER=1` is no longer used here: disabling DMA-BUF can still crash on NVIDIA's EGL fallback path, and forcing X11 does not provide a reliable workaround for NVIDIA users.

## 🪲 Where to Report Issues?

To save everyone's time, please route your feedback to the correct repository:

* 🔴 **App Bugs → [Report to Upstream](https://github.com/AkaraChen/aghub/issues)**
  *(e.g., UI glitches, AI agent config errors, Wayland rendering complaints, feature requests)*

* 🟢 **Packaging Bugs → [Report Here](https://github.com/losslauralin/aur-aghub-bin/issues)**
  *(e.g., Checksum mismatches, installation failures, missing `.desktop` files, outdated package version)*
