# Project Documentation: AES-128/192/256 Encryption over UART with GUI

## 1. Project Overview

This project implements the AES (Advanced Encryption Standard) symmetric
encryption algorithm in hardware on an FPGA (Xilinx Artix-7,
XC7A35T-FTG256-1), supporting all three standard key sizes — 128, 192,
and 256 bits. A user selects the desired mode and enters a key and
plaintext through a Python desktop GUI on a PC. The GUI transmits this
data to the FPGA over a UART (serial) connection; the FPGA performs the
AES encryption in real hardware and transmits the resulting ciphertext
back, which the GUI displays.

**Key features:**
- Hardware AES encryption for 128/192/256-bit keys, verified against the
  official FIPS-197 published test vectors
- Custom UART communication protocol for framing requests/responses
- Python/Tkinter GUI for mode selection, key/data entry, and result display
- On-board status feedback via LEDs and a 16x2 character LCD

**Current scope:** encryption only (decryption was implemented and
verified in simulation for all three key sizes, but excluded from this
hardware build due to FPGA resource constraints — see Section 6).

## 2. Design and Architecture

### 2.1 System block diagram

```
┌───────────────────┐      UART (115200 baud, 8N1)      ┌──────────────────────────┐
│   PC (Python GUI)  │◄──────────────────────────────────►│   FPGA (XC7A35T)         │
│                    │   via external USB-to-TTL adapter   │                          │
│  - Mode selection  │   wired to PMOD IO_0/IO_1           │  uart_rx / uart_tx       │
│  - Key/data entry  │                                     │        ↓                 │
│  - Send / Result   │                                     │  controller.v (FSM)      │
└───────────────────┘                                     │        ↓                 │
                                                            │  aes_wrapper.v           │
                                                            │  (selects 128/192/256)   │
                                                            │        ↓                 │
                                                            │  aes_enc.v (iterative)   │
                                                            │        ↓                 │
                                                            │  key_gen.v (key schedule)│
                                                            │                          │
                                                            │  LEDs + 16x2 LCD status  │
                                                            └──────────────────────────┘
```

### 2.2 Communication protocol

**Request (PC → FPGA):**
```
[0xAA][MODE][OP][KEY bytes][DATA bytes][0x55]
```
- `MODE`: `0x00`=AES-128, `0x01`=AES-192, `0x02`=AES-256
- `OP`: `0x00`=encrypt (decrypt reserved for future use — see Section 6)
- `KEY`: 16/24/32 bytes depending on MODE
- `DATA`: 16 bytes (plaintext block)

**Response (FPGA → PC):**
```
[0xAA][RESULT — 16 bytes][0x55]
```

Fixed start (`0xAA`) and end (`0x55`) marker bytes let the receiver detect
a corrupted or incomplete transmission (a framing error), rather than
silently processing invalid data.

**Byte order:** big-endian — the first byte transmitted is the
most-significant byte of the key/data value, matching standard AES/FIPS-197
notation.

### 2.3 Architectural decision: iterative vs. fully-unrolled AES core

The AES round transformation (SubBytes, ShiftRows, MixColumns, AddRoundKey)
can be implemented in hardware two ways:
- **Fully unrolled**: build separate physical logic for every round (10-14
  copies). Faster (one clock cycle per encryption) but uses far more chip
  resources.
- **Iterative**: build one round's worth of logic and reuse it every clock
  cycle via a counter and state machine. Takes multiple clock cycles per
  encryption, but uses roughly 10-14x less hardware.

This project uses the **iterative** approach. Initial development used a
fully-unrolled design, but supporting all three key sizes simultaneously
exceeded the target FPGA's available logic resources (specifically,
"F7 Mux" over-utilization was reported during Place & Route: 22,201
required vs. 16,300 available). Since the application is limited by a
115200 baud UART link regardless, the extra clock cycles per encryption
(roughly ROUNDS+2 cycles) are functionally irrelevant, making the
iterative approach the correct engineering tradeoff here.

## 3. Implementation Approach

1. Started from an open-source AES-128/192/256 Verilog implementation
   (encrypt and decrypt cores, parameterized by key size).
2. Identified and fixed a key-schedule array-bounds bug affecting AES-192
   and AES-256 (present in the original source; AES-128 happened to work
   because its word-count math divides evenly, masking the bug).
3. Designed and implemented a custom UART receiver/transmitter (`uart_rx.v`,
   `uart_tx.v`) and a packet-parsing controller FSM (`controller.v`) to
   bridge serial communication to the AES core.
4. Designed `aes_wrapper.v` to select between the three AES core
   instances at runtime based on a mode signal, since the underlying
   core's key size is a compile-time Verilog parameter.
5. Diagnosed and resolved an FPGA resource over-utilization issue during
   hardware implementation, ultimately redesigning the AES core from a
   fully-unrolled to an iterative architecture (see Section 2.3).
6. Built a Python/Tkinter GUI (`aes_gui.py`) using `pyserial` for UART
   communication, including input validation, a background thread for
   non-blocking serial I/O, and a built-in FIPS-197 test-vector loader for
   quick correctness verification.
7. Added on-board status feedback: LEDs (busy/error indicators) and a
   16x2 character LCD (mode + status display).
8. Verified correctness at each stage: simulation testbenches against
   official FIPS-197 vectors (all three key sizes), followed by
   end-to-end hardware testing via the GUI.

## 4. Module Descriptions

| Module | Description |
|---|---|
| `sbox.v` / `inv_sbox.v` | AES S-box and inverse S-box lookup tables (SubBytes/InvSubBytes) |
| `M2.v`, `M3.v`, `M9.v`, `M11.v`, `M13.v`, `M14.v` | Galois-Field multiplication lookup tables used by MixColumns/InvMixColumns |
| `key_gen.v` | Expands the input key into all round keys required by the selected key size |
| `aes_enc.v` | Iterative AES encryption core: applies one round per clock cycle, reusing shared SubBytes/ShiftRows/MixColumns/AddRoundKey logic, controlled by an internal state machine and round counter |
| `aes_wrapper.v` | Instantiates the three AES-128/192/256 cores and multiplexes the correct one's output based on the runtime-selected mode |
| `uart_rx.v` | 8-N-1 UART receiver (115200 baud @ 24MHz clock) |
| `uart_tx.v` | 8-N-1 UART transmitter |
| `controller.v` | Top-level protocol FSM: parses incoming request packets, drives the AES wrapper, assembles and sends the response packet, and raises busy/error status signals |
| `lcd_driver.v` | Drives the onboard 16x2 character LCD, displaying the selected mode and current status |
| `top.v` | Top-level module connecting all of the above to the physical board I/O (clock, reset, UART pins, LEDs, LCD) |
| `aes_gui.py` | Python/Tkinter desktop application: mode/operation selection, key/data entry with validation, serial communication via `pyserial`, and result display |

## 5. Build, Run, and Testing Instructions

### 5.1 Hardware build (Vivado)

1. Create a Vivado project targeting the XC7A35T-FTG256-1 part.
2. Add all `.v` files listed in Section 4 as Design Sources, with `top.v`
   set as the top module.
3. Add `aes_uart_top.xdc` as the constraints file.
4. Run Synthesis, then Implementation, then Generate Bitstream.
5. Program the device via Vivado Hardware Manager (board's onboard USB-C,
   JTAG mode).

### 5.2 Hardware setup

1. Set configuration switches for Master SPI boot mode (or JTAG for direct
   load).
2. Wire an external 3.3V USB-to-TTL serial adapter to the board's PMOD
   connector: adapter TX → PMOD IO_1, adapter RX → PMOD IO_0, adapter
   GND → board GND. (The onboard USB-C is JTAG/programming only, not
   wired to UART on this board.)
3. Set the reset slide switch (SS0) to the run (non-reset) position.

### 5.3 Running the GUI

```
pip install pyserial
python aes_gui.py
```
1. Select the USB-TTL adapter's COM port (Refresh if not listed).
2. Select the desired AES mode (128/192/256).
3. Enter a key and plaintext in hex, or click "Load FIPS-197 Test Vector"
   to auto-fill a known-correct example.
4. Click Send; the result field displays the returned ciphertext.

### 5.4 Verification

Each mode was verified against the official FIPS-197 test vectors:

| Mode | Key | Plaintext | Expected Ciphertext |
|---|---|---|---|
| AES-128 | `000102030405060708090a0b0c0d0e0f` | `00112233445566778899aabbccddeeff` | `69c4e0d86a7b0430d8cdb78070b4c55a` |
| AES-192 | `000102030405060708090a0b0c0d0e0f1011121314151617` | `00112233445566778899aabbccddeeff` | `dda97ca4864cdfe06eaf70a0ec0d7191` |
| AES-256 | `000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f` | `00112233445566778899aabbccddeeff` | `8ea2b7ca516745bfeafc49904b496089` |

All three were confirmed matching on real hardware via the GUI.


