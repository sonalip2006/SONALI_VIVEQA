# Integration Notes — AES + UART + GUI

## Files in this set
- `uart_rx.v` — 8-N-1 UART receiver, 208 clocks/bit (24 MHz / 115200 baud)
- `uart_tx.v` — 8-N-1 UART transmitter, same timing
- `aes_wrapper.v` — instantiates all 3 key-size AES cores from the repo and
  muxes by runtime mode/op (needed because `KEY_SIZE` in `aes_enc.v`/`aes_dec.v`
  is a compile-time Verilog parameter, not a runtime signal)
- `controller.v` — parses the UART packet, drives the wrapper, sends the result back
- `top.v` — wires it all together
- `aes_uart_top.xdc` — pin constraints (UART + reset pins still TODO — see below)

## ⚠️ Before synthesizing
1. **UART pins are unconfirmed.** Get them from Anmaya Technologies or trace
   the schematic yourself. Do not guess.
2. **Reset button pin is unconfirmed.** Either get it, or wire `rst_n` to a
   slide switch instead (pin is confirmed in the .xdc, commented out).
3. **Simulate first.** I don't have a Verilog simulator available in this
   environment to compile-check this code, so treat it as a solid starting
   point, not verified-working RTL. At minimum, write a testbench that:
   - Sends a full packet (start byte, mode, op, key, data, end byte) into
     `controller.v` bit-by-bit through a simulated `uart_rx`
   - Confirms `aes_data_out` matches a known FIPS-197 test vector
   - Confirms the correct bytes come back out of `uart_tx`

## Packet protocol (must match your Python GUI exactly)

Request (PC → FPGA):
```
[0xAA][MODE][OP][KEY bytes][DATA bytes][0x55]
```
- MODE: `0x00`=AES-128, `0x01`=AES-192, `0x02`=AES-256
- OP: `0x00`=encrypt, `0x01`=decrypt
- KEY: 16/24/32 bytes depending on MODE
- DATA: 16 bytes (plaintext if OP=0, ciphertext if OP=1)

Response (FPGA → PC):
```
[0xAA][RESULT — 16 bytes][0x55]
```

## Byte order — important
`controller.v` uses shift registers to accumulate bytes: the first byte you
send becomes the **most-significant** byte of the key/data bus, and each
subsequent byte shifts in below it — this is standard big-endian AES/FIPS-197
notation (e.g. sending `00 01 02 ... 0f` for a key makes `0x00` the top byte,
matching how that same hex string reads in the FIPS-197 spec and in this
repo's own `aes_enc_tb.v`). This matches a plain hex string typed left-to-right
into the GUI's key/data fields — no special reversal needed on the Python
side. Still worth confirming end-to-end once, since byte-order bugs are a
classic place these projects break:

Example AES-128 vector (from `aes_enc_tb.v` in your repo):
- Key: `00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f`
- Plaintext: `00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee ff`
- Expected ciphertext: `69 c4 e0 d8 6a 7b 04 30 d8 cd b7 80 70 b4 c5 5a`

If your GUI sends this exact key+plaintext and mode=0/op=0, and the board
sends back exactly that ciphertext, your byte ordering is correct end to end.
If the bytes come back reversed or scrambled, that's a byte-order mismatch
between your Python packing and the Verilog unpacking above — fix it there
before debugging anything else.

## Python side (pyserial) — minimal packet builder sketch
```python
import serial

def build_packet(mode, op, key_bytes, data_bytes):
    assert len(key_bytes) in (16, 24, 32)
    assert len(data_bytes) == 16
    return bytes([0xAA, mode, op]) + key_bytes + data_bytes + bytes([0x55])

def send_and_receive(port, packet):
    with serial.Serial(port, 115200, timeout=2) as ser:
        ser.write(packet)
        response = ser.read(18)   # 0xAA + 16 result bytes + 0x55
        assert response[0] == 0xAA and response[-1] == 0x55, "framing error"
        return response[1:17]
```

## Suggested test order
1. Simulate `controller.v` + `aes_wrapper.v` together against the FIPS-197
   vector above, entirely in your Verilog simulator — no hardware needed.
2. Once simulation passes, synthesize and program the board.
3. Test with a serial terminal (PuTTY / RealTerm) sending raw hex bytes
   before trusting your full Python GUI — isolates GUI bugs from hardware bugs.
4. Only then run the full GUI → UART → FPGA → UART → GUI loop.
