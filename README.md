# aghub-bin

Unofficial AUR package for [aghub](https://github.com/AkaraChen/aghub).

This repo only contains the Arch packaging bits: `PKGBUILD`, `.SRCINFO`, the desktop entry, and the workflow that tracks upstream releases. The app itself is maintained by the upstream project.

## Install

The package is available on the [AUR](https://aur.archlinux.org/packages/aghub-bin):

```bash
paru -S aghub-bin
# or
yay -S aghub-bin
```

## NVIDIA + Wayland

The packaged desktop launcher sets `__NV_DISABLE_EXPLICIT_SYNC=1`.

Why this is here: with proprietary NVIDIA drivers on Wayland, WebKitGTK can crash when its DMA-BUF renderer negotiates the `linux-drm-syncobj-v1` explicit sync protocol with the driver. Disabling explicit sync makes NVIDIA fall back to implicit sync while keeping hardware acceleration enabled.

If you start aghub from the app launcher, no extra step is needed. If you run it from a terminal, use the same environment variable yourself:

```bash
__NV_DISABLE_EXPLICIT_SYNC=1 aghub
```

`GDK_BACKEND=x11 WEBKIT_DISABLE_DMABUF_RENDERER=1` is no longer used here: disabling DMA-BUF can still crash on NVIDIA's EGL fallback path, and forcing X11 does not provide a reliable workaround for NVIDIA users.

## Where to report issues

Please send app bugs to upstream and packaging bugs here.

Report to [AkaraChen/aghub](https://github.com/AkaraChen/aghub/issues) for:

- UI bugs
- agent configuration behavior
- feature requests
- runtime bugs that are not caused by the AUR package

Report to [this repo](https://github.com/losslauralin/aur-aghub-bin/issues) for:

- checksum mismatches
- install failures
- missing or wrong desktop entry
- outdated package version

If you are not sure which one it is, open the issue here and include the command you ran plus the full error output.
