# singularity-installer

The system installer and first-boot setup (OOBE) for [Sinty OS](https://github.com/singularityos-lab) and the Singularity Desktop Environment.

Run it in two modes:

- default: the installer, provisioning the Atom Loops layout (ESP + verified EROFS root + persistent `/var`) onto a target disk.
- `--oobe`: the first-boot setup, run once on a freshly provisioned machine to create the user, region, keyboard and hostname.

## Requirements

- [Meson](https://mesonbuild.com/) >= 1.0
- [Vala](https://vala.dev/) compiler
- GTK4
- libgee-0.8
- json-glib-1.0
- libxml-2.0
- [libsingularity](https://github.com/singularityos-lab/libsingularity)

## Build & Install

```sh
meson setup build
meson compile -C build
meson install -C build
```

## License

GPL-3.0-only - see [LICENSE](LICENSE).
