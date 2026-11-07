# M5Unit-Fingerprint2-Go

[![test](https://github.com/nicolasmmb/M5Unit-Fingerprint2-Go/actions/workflows/test.yml/badge.svg)](https://github.com/nicolasmmb/M5Unit-Fingerprint2-Go/actions/workflows/test.yml)

Pure-Go driver for the **M5Stack Unit Fingerprint2 (A-K323CP)** for TinyGo on
the ESP32. No C, C++, CGo, Arduino or ESP-IDF: the Grove UART protocol is
implemented in Go.

## Features

- Full command coverage: image, feature generation, match, search, templates,
  enrollment, identification, LED, notepad, INF page, registers and system
  settings.
- Module-driven enrollment (`AutoEnroll`) and identification (`AutoIdentify`)
  exposed as event streams.
- Correct data-packet handling (only ACKs carry a confirmation byte).
- Concurrent-safe: operations are serialized; sessions are cancellable with
  `context` and capped at 60 s.
- Transfer buffers are reused: image uploads and template transfers do not
  allocate per frame/chunk.
- Host test suite with an in-memory transport (`go test ./...`).

## Hardware

| Signal | Pin |
|---|---|
| UART | 115200 8N1 |
| TX | G32 |
| RX | G33 |
| Grove | 5 V / GND |

The unit sleeps until touched unless `SetWorkMode(1)` is used.

## Install

```bash
go get github.com/nicolasmmb/M5Unit-Fingerprint2-Go@v0.1.0
```

## Quick start

```go
uart := machine.UART1
_ = uart.Configure(machine.UARTConfig{
    BaudRate: 115200,
    TX:       machine.GPIO32,
    RX:       machine.GPIO33,
})

dev := finger2.New(uart)
if err := dev.InitWithTimeout(10 * time.Second); err != nil {
    panic(err)
}
_ = dev.SetWorkMode(1)

// Read a finger: Capture -> GenChar -> Search.
ok, _, _ := dev.Capture()
if ok {
    dev.GenChar(1)                       // convert the image into features
    res, _ := dev.Search(1, 0, dev.Capacity)
    if res.Matched {
        println("page", res.Page, "score", res.Score)
    }
}
```

`Search` compares the feature buffer, not the raw image, so a read is always
`Capture` → `GenChar(1)` → `Search(1, ...)`.

## API overview

| Area | Functions |
|---|---|
| Construction | `NewTransport(Transport)` on any chip, `New(*machine.UART)` on ESP32 |
| System | `Init`, `InitWithTimeout`, `InitContext`, `Handshake`, `Activate`, `ModuleStatus`, `GetFirmwareVersion`, `ReadSysParams`, `SetSleepTime`, `GetSleepTime`, `SetWorkMode`, `GetWorkMode`, `SaveConfig`, `GetSN`, `CheckSensor`, `GetRandom`, `WriteReg`, `SetMatchLevel`, `WaitWakeup`, `SetWakeupHandler` |
| Biometrics | `Capture`, `GetEnrollImage`, `GenChar`, `Match`, `Search`, `SearchNow`, `RegModel`, `Store`, `LoadChar`, `Delete`, `Empty`, `Cancel` |
| Enrollment | `StartAutoEnroll`, `NextEnrollEvent`, `AutoEnroll`, `StartAutoIdentify`, `NextIdentifyEvent`, `AutoIdentify` |
| Templates | `ValidTemplates`, `ReadIndexTable`, `FirstFreePage`, `UploadTemplate`, `UploadTemplateAuto`, `DownloadTemplate`, `DownloadTemplateAuto` |
| Image | `UpImage`, `UpImageTo`, `ImageInfo`, `ReadINF`, `ReadINFTo` |
| Extras | `ReadNotepad`, `WriteNotepad`, `ControlLED`, `SetLED` |

### Concurrency

A `Device` is safe for concurrent use. One-shot operations serialize on an
internal lock. `StartAutoEnrollContext` and `StartAutoIdentifyContext` hold the
device until the terminal stage, `Cancel` or the context deadline (60 s max).

## Examples

Runnable samples live in [`examples/`](examples/). Build them with:

```bash
make examples
```

They cover reads, enrollment, identification, image upload, template round
trips, manual match, system information, notepad, INF page, context
cancellation and concurrent callers.

## Protocol notes

- Frame: `EF 01 | address(4) | PID | length(2) | payload | checksum(2)`.
- PID `0x07` (ACK) payload starts with the confirmation byte; data packets
  (`0x02`/`0x08`) carry raw data from byte 9. Mixing the two drops one byte per
  packet and corrupts image transfers.
- Image: 80×208, 4 bits per pixel, 8320 bytes, low nibble first.
- `Init` reports the module match level but does not force it; call
  `SetMatchLevel` when a specific level is required.
- `IAPReset` and a rainbow LED mode are not part of this firmware's protocol.

## Board support

The driver is board agnostic. The core talks to a `Transport` interface
(`Write`, `ReadByte`, `Buffered`), and `NewTransport` is the constructor that
takes it:

```go
d, err := finger2.NewTransport(myUART)   // any chip, any byte stream
if err != nil {
    println("finger2:", err.Error())
    return
}
```

`machine.UART`, a USB CDC port, a network socket or an in-memory pipe all
satisfy `Transport`. The ESP32 helper `New(*machine.UART)` is a convenience on
top of `NewTransport` and exists only under `//go:build esp32`, because it takes
the concrete machine type.

Verified by compiling `NewTransport` for each target:

| Target | Chip | Result |
|---|---|---|
| `m5stick-c` | ESP32 | ok |
| `m5stamp-c3` | ESP32-C3 | ok |
| `pico` | RP2040 | ok |
| `arduino-nano33` | nRF52840 | ok |

CI repeats this in the `agnostic` job.

## Testing

```bash
make test        # go test ./...
```

The tests use an in-memory transport and cover framing, checksums, command
parsing, buffer ownership, concurrency and context cancellation.

## License

MIT — see [LICENSE](LICENSE).
