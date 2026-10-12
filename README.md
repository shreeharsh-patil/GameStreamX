# GameStreamX

[![CI](https://github.com/shreeharsh-patil/GameStreamX/actions/workflows/ci.yml/badge.svg)](https://github.com/shreeharsh-patil/GameStreamX/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-0.7.0-blue.svg)](Directory.Build.props)
[![Target](https://img.shields.io/badge/.NET-10.0-purple.svg)](Directory.Build.props)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-lightgrey.svg)](COMPATIBILITY.md)

**GameStreamX** enables playing PC games directly from cloud storage (Google Drive and rclone-supported backends) on Windows without requiring full local downloads.

Built upon proven low-level components — [WinFsp](https://winfsp.dev/) (Windows user-mode file system) and [rclone](https://rclone.org/) (cloud storage backends and sparse VFS caching) — GameStreamX adds intelligent mounting orchestration, access telemetry parsing, predictive caching, prefetching, game compatibility layers, and a modern WPF desktop UI.

---

## Key Features

- **Direct Cloud Mounting**: Mount Google Drive or remote cloud storage to a dedicated Windows drive letter (e.g. `X:`) in user-space via WinFsp without requiring kernel drivers.
- **Sparse VFS Caching**: Downloads and caches only the file chunks that the game actually reads. Game starts playing within seconds, not hours.
- **Predictive Prefetching & Game-Aware Protocol**:
  - Access-pattern learning stores profile traces of game startups and level transitions in SQLite.
  - Anticipates read spikes and queues priority chunks ahead of demand to eliminate stutter.
  - Optional Game-Aware named pipe protocol for game-engine direct hint signaling.
- **Three Game Execution Modes**:
  - **Cloud Direct**: Run directly off the mounted cloud volume.
  - **Hybrid Optimized**: Keep essential executables and config files local while symlinking large asset archives (`.pak`, `.bin`, `.vpk`) into the cloud mount.
  - **Full Local Fallback**: Resume-safe local copying for games requiring high-frequency random I/O or anti-cheat isolation.
- **Disk Safety & Smart Eviction**:
  - Monitors NTFS sparse allocations (`GetCompressedFileSizeW`) and enforces cache budgets with automatic low-space eviction guards.
  - Atomic configuration management with DPAPI encrypted credential storage.
- **Comprehensive Desktop UI & CLI**:
  - Modern WPF dashboard with real-time throughput sparklines, drive mount manager, game library, performance telemetry, and diagnostic exports.
  - Command-line interface (`gsx.exe`) for automation, mounting, and PE inspection.

---

## Architecture Overview

```text
 ┌────────────────────────── GameStreamX.Desktop (WPF, MVVM) ─────────────────────────┐   gsx.exe (CLI)
 │ Dashboard · Cloud Drives · Game Library · Accelerator · Smart Cache · Perf · ...   │   benchmarks
 └───────────────────────────────────────┬────────────────────────────────────────────┘        │
                                         ▼                                                     ▼
 ┌──────────────────────────────── GameStreamX.App: AppHost ──────────────────────────────────────┐
 │ settings · rclone discovery · mounts ⇄ engine wiring · metrics (1 Hz) · disk guard · games     │
 └──────┬──────────────┬────────────────┬───────────────────┬──────────────────┬──────────────────┘
        ▼              ▼                ▼                   ▼                  ▼
  Mount (rclone)   Cache            Streaming            Games              Providers / Diagnostics
  RcloneMountSvc   CacheInspector   StreamingEngine      Library (SQLite)   provider descriptors
  LogTailer+Parser DiskSafetyGuard  predictors           Scanner + PE       redaction, DPAPI,
  RcClient         CacheIndex       PrefetchQueue/Sched  Compatibility      dependency checks,
  GoogleDrive conn CacheMaintenance ProfileStore(SQLite) Launcher (job obj) diagnostic ZIP
                                    GameAware            Hybrid / FullLocal
                                    Simulator            Preparer
        │                                  ▲ AccessEvents (offset, size, hit/miss, wait)
        ▼                                  │
  rclone mount (child process) ── -vv log file ──► LogTailer ──► RcloneLogParser
        │  --vfs-cache-mode full, --buffer-size 0, --rc on 127.0.0.1 (random user/pass via env)
        ▼
  WinFsp drive X:  ⇄  sparse VFS cache on NTFS  ⇄  Google Drive / any rclone backend
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for full architectural documentation.

---

## Quick Start & Prerequisites

### Prerequisites

- **OS**: Windows 10 (1809+) or Windows 11 x64
- **Runtime**: [.NET 10.0 Runtime / SDK](https://dotnet.microsoft.com/)
- **Filesystem Driver**: [WinFsp](https://winfsp.dev/) (2023 or newer)
- **Cloud Backend**: [rclone](https://rclone.org/) (downloaded automatically via script or bundled in release)

### Building from Source

1. **Clone repository**:
   ```bash
   git clone https://github.com/shreeharsh-patil/GameStreamX.git
   cd GameStreamX
   ```

2. **Fetch rclone binary**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File installer/fetch-rclone.ps1
   ```

3. **Build the solution**:
   ```powershell
   dotnet build GameStreamX.slnx -c Release
   ```

4. **Run tests**:
   ```powershell
   dotnet test tests/GameStreamX.Tests
   ```

5. **Launch Desktop App**:
   ```powershell
   dotnet run --project src/GameStreamX.Desktop -c Release
   ```

---

## Performance & Benchmarks

Measured on a 70 Mbps connection with 80 ms latency (loading DRM-free demo game level 2):

| Mode | Cold Load | Warm Load | Download Volume | Peak RAM |
|---|---|---|---|---|
| **Stock rclone mount** | 56.5 s – 65.2 s | 56.5 s | 551 MiB | 142 MiB |
| **GameStreamX Cold** | 20.3 s – 21.0 s | 20.3 s | 117 MiB (4.7× reduction) | 57 MiB |
| **GameStreamX Prepared (Warm)** | **7.7 s – 8.2 s** | **0.15 s – 0.27 s** | **39 MiB** | 58 MiB |

Full benchmark data and replication commands are documented in [BENCHMARKS.md](BENCHMARKS.md).

---

## Project Structure

- `src/GameStreamX.Core` — Fundamental domain models, metrics, settings, unit formatting, disk P/Invoke.
- `src/GameStreamX.Diagnostics` — Redacted logging, DPAPI credential store, environment dependency checks.
- `src/GameStreamX.Mount` — rclone process lifecycle, flag builders, rotation-safe tailer, log parser, Google OAuth state machine.
- `src/GameStreamX.Cache` — Sparse file inspections, budget enforcement, and disk safety guard.
- `src/GameStreamX.Streaming` — Predictive prefetch engine, scheduling policies, Game-Aware IPC protocol, trace simulator.
- `src/GameStreamX.Games` — SQLite game catalog, PE inspection, compatibility rules, hybrid symlink preparer, process launcher.
- `src/GameStreamX.Providers` — Cloud provider descriptors and capabilities.
- `src/GameStreamX.App` — Application host orchestrating telemetry, engine, and services.
- `src/GameStreamX.Desktop` — Modern WPF MVVM application with charts and dialogs.
- `src/GameStreamX.Cli` — `gsx` command-line utility.
- `src/GameStreamX.SimCloud` — Local throttled HTTP cloud simulator for reproducible network conditions.
- `tests/` — Unit test suite, integration harness, and simulated demo game.
- `installer/` — Inno Setup packaging scripts and release builders.

---

## Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Build Status](BUILD_STATUS.md)
- [Compatibility Matrix](COMPATIBILITY.md)
- [Known Limitations](KNOWN_LIMITATIONS.md)
- [Google Drive Setup Guide](docs/GOOGLE_DRIVE_SETUP.md)
- [Game-Aware Protocol Specification](docs/GAME_AWARE_PROTOCOL.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)

---

## License & Notices

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for licenses and notices regarding third-party components (rclone, WinFsp, CommunityToolkit.Mvvm).
