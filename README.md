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

## 🛠️ Troubleshooting (Wayland Users)

Because `aghub` relies on WebKit2GTK, you may encounter rendering issues (e.g., blank, black, or transparent windows) under a native Wayland session.

* **Launching via App Icon:** The included `.desktop` file already forces X11 mode (`GDK_BACKEND=x11`) to prevent these issues.

* **Launching via Terminal:** If you run the GUI directly from your terminal, please apply the compatibility variables manually:

  ```bash
  GDK_BACKEND=x11 WEBKIT_DISABLE_DMABUF_RENDERER=1 aghub
  ```

## 🪲 Where to Report Issues?

To save everyone's time, please route your feedback to the correct repository:

* 🔴 **App Bugs → [Report to Upstream](https://github.com/AkaraChen/aghub/issues)**
  *(e.g., UI glitches, AI agent config errors, Wayland rendering complaints, feature requests)*

* 🟢 **Packaging Bugs → [Report Here](https://github.com/losslauralin/aur-aghub-bin/issues)**
  *(e.g., Checksum mismatches, installation failures, missing `.desktop` files, outdated package version)*
