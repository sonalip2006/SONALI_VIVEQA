#!/usr/bin/env python3
"""
aes_gui.py

Tkinter GUI for the AES-128/192/256 + UART FPGA project.

Talks to the FPGA board (via an external USB-to-TTL serial adapter wired
to the PMOD header, per the project's constraints file) using the packet
protocol defined in controller.v:

  Request  (PC -> FPGA):
    [0xAA][MODE][OP][KEY bytes][DATA bytes][0x55]
      MODE: 0x00=AES-128, 0x01=AES-192, 0x02=AES-256
      OP:   0x00=encrypt, 0x01=decrypt
      KEY:  16/24/32 bytes depending on MODE
      DATA: 16 bytes (plaintext if OP=0, ciphertext if OP=1)

  Response (FPGA -> PC):
    [0xAA][RESULT -- 16 bytes][0x55]

Requires: pip install pyserial
"""

import tkinter as tk
from tkinter import ttk, messagebox
import threading
import queue

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    serial = None  # handled at runtime with a clear error message

BAUD_RATE = 115200
SERIAL_TIMEOUT_S = 3

MODE_TO_CODE = {"AES-128": 0x00, "AES-192": 0x01, "AES-256": 0x02}
MODE_KEY_BYTES = {"AES-128": 16, "AES-192": 24, "AES-256": 32}
OP_TO_CODE = {"Encrypt": 0x00, "Decrypt": 0x01}

START_BYTE = 0xAA
END_BYTE = 0x55
DATA_BYTES_LEN = 16


class AESGuiApp:
    def __init__(self, root):
        self.root = root
        self.root.title("AES-128/192/256 UART Controller")
        self.root.geometry("560x680")
        self.root.resizable(True, True)

        # queue used to safely pass results from the worker thread back
        # to the Tkinter main thread
        self.result_queue = queue.Queue()

        self._build_widgets()
        self._refresh_ports()

        # poll the queue periodically for results from the serial thread
        self.root.after(100, self._poll_queue)

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------
    def _build_widgets(self):
        pad = {"padx": 10, "pady": 6}

        title = ttk.Label(
            self.root, text="AES-128/192/256 over UART", font=("Segoe UI", 14, "bold")
        )
        title.pack(pady=(12, 4))

        # ---------------- Serial port selection ----------------
        port_frame = ttk.LabelFrame(self.root, text="Serial Connection")
        port_frame.pack(fill="x", **pad)

        ttk.Label(port_frame, text="Port:").grid(row=0, column=0, padx=6, pady=6, sticky="w")
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(port_frame, textvariable=self.port_var, width=20, state="readonly")
        self.port_combo.grid(row=0, column=1, padx=6, pady=6, sticky="w")

        refresh_btn = ttk.Button(port_frame, text="Refresh", command=self._refresh_ports)
        refresh_btn.grid(row=0, column=2, padx=6, pady=6)

        ttk.Label(port_frame, text=f"Baud: {BAUD_RATE} (fixed)").grid(
            row=0, column=3, padx=6, pady=6, sticky="w"
        )

        # ---------------- Mode selection ----------------
        mode_frame = ttk.LabelFrame(self.root, text="AES Mode")
        mode_frame.pack(fill="x", **pad)

        self.mode_var = tk.StringVar(value="AES-128")
        for i, mode in enumerate(["AES-128", "AES-192", "AES-256"]):
            rb = ttk.Radiobutton(
                mode_frame, text=mode, variable=self.mode_var, value=mode,
                command=self._on_mode_change
            )
            rb.grid(row=0, column=i, padx=12, pady=6, sticky="w")

        # ---------------- Operation selection ----------------
        # NOTE: this hardware build is ENCRYPT-ONLY (decrypt cores were
        # removed to fit the FPGA's resource budget -- see project notes).
        # Decrypt is shown but disabled so it can't be selected by mistake;
        # selecting it on this build would silently just encrypt anyway.
        op_frame = ttk.LabelFrame(self.root, text="Operation")
        op_frame.pack(fill="x", **pad)

        self.op_var = tk.StringVar(value="Encrypt")
        for i, op in enumerate(["Encrypt", "Decrypt"]):
            rb = ttk.Radiobutton(
                op_frame, text=op, variable=self.op_var, value=op,
                command=self._on_op_change,
                state=("normal" if op == "Encrypt" else "disabled")
            )
            rb.grid(row=0, column=i, padx=12, pady=6, sticky="w")

        ttk.Label(
            op_frame, text="(Decrypt not available on this hardware build)",
            foreground="#888", font=("Segoe UI", 8, "italic")
        ).grid(row=1, column=0, columnspan=2, padx=12, pady=(0, 4), sticky="w")

        # ---------------- Key input ----------------
        key_frame = ttk.LabelFrame(self.root, text="Key (hex)")
        key_frame.pack(fill="x", **pad)

        self.key_hint_var = tk.StringVar()
        ttk.Label(key_frame, textvariable=self.key_hint_var, foreground="#555").pack(
            anchor="w", padx=6, pady=(4, 0)
        )
        self.key_entry = ttk.Entry(key_frame, font=("Consolas", 11))
        self.key_entry.pack(fill="x", padx=6, pady=(2, 8))

        # ---------------- Data input ----------------
        data_frame = ttk.LabelFrame(self.root, text="Data (hex)")
        data_frame.pack(fill="x", **pad)

        self.data_hint_var = tk.StringVar()
        ttk.Label(data_frame, textvariable=self.data_hint_var, foreground="#555").pack(
            anchor="w", padx=6, pady=(4, 0)
        )
        self.data_entry = ttk.Entry(data_frame, font=("Consolas", 11))
        self.data_entry.pack(fill="x", padx=6, pady=(2, 8))

        # ---------------- Load test vector helper ----------------
        vector_btn = ttk.Button(
            self.root, text="Load FIPS-197 Test Vector (for this mode)",
            command=self._load_test_vector
        )
        vector_btn.pack(pady=(0, 6))

        # ---------------- Send button ----------------
        self.send_btn = ttk.Button(self.root, text="Send", command=self._on_send_clicked)
        self.send_btn.pack(pady=6)

        # ---------------- Output ----------------
        out_frame = ttk.LabelFrame(self.root, text="Result")
        out_frame.pack(fill="x", **pad)

        self.result_var = tk.StringVar(value="(no result yet)")
        result_label = ttk.Label(
            out_frame, textvariable=self.result_var, font=("Consolas", 11),
            wraplength=520
        )
        result_label.pack(anchor="w", padx=6, pady=6)

        # ---------------- Status / log ----------------
        status_frame = ttk.LabelFrame(self.root, text="Status")
        status_frame.pack(fill="both", expand=True, **pad)

        self.status_text = tk.Text(status_frame, height=6, state="disabled", font=("Consolas", 9))
        self.status_text.pack(fill="both", expand=True, padx=6, pady=6)

        self._update_hints()

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    def _log(self, msg):
        self.status_text.configure(state="normal")
        self.status_text.insert("end", msg + "\n")
        self.status_text.see("end")
        self.status_text.configure(state="disabled")

    def _refresh_ports(self):
        if serial is None:
            self._log("ERROR: pyserial is not installed. Run: pip install pyserial")
            self.port_combo["values"] = []
            return
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self.port_combo["values"] = ports
        if ports:
            self.port_combo.current(0)
            self._log(f"Found {len(ports)} serial port(s): {', '.join(ports)}")
        else:
            self._log("No serial ports found. Is the USB-TTL adapter connected?")

    def _on_mode_change(self):
        self._update_hints()

    def _on_op_change(self):
        self._update_hints()

    def _update_hints(self):
        mode = self.mode_var.get()
        op = self.op_var.get()
        key_bytes = MODE_KEY_BYTES[mode]
        self.key_hint_var.set(f"Enter {key_bytes} bytes as hex ({key_bytes*2} hex characters, no spaces)")
        data_label = "Plaintext" if op == "Encrypt" else "Ciphertext"
        self.data_hint_var.set(f"{data_label}: enter 16 bytes as hex (32 hex characters, no spaces)")

    def _load_test_vector(self):
        """Loads the FIPS-197 test vector matching the currently selected mode,
        so you can verify the whole chain against a known-correct answer."""
        mode = self.mode_var.get()
        vectors = {
            "AES-128": {
                "key": "000102030405060708090a0b0c0d0e0f",
                "plaintext": "00112233445566778899aabbccddeeff",
                "ciphertext": "69c4e0d86a7b0430d8cdb78070b4c55a",
            },
            "AES-192": {
                "key": "000102030405060708090a0b0c0d0e0f1011121314151617",
                "plaintext": "00112233445566778899aabbccddeeff",
                "ciphertext": "dda97ca4864cdfe06eaf70a0ec0d7191",
            },
            "AES-256": {
                "key": "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
                "plaintext": "00112233445566778899aabbccddeeff",
                "ciphertext": "8ea2b7ca516745bfeafc49904b496089",
            },
        }
        v = vectors[mode]
        self.op_var.set("Encrypt")
        self._update_hints()
        self.key_entry.delete(0, "end")
        self.key_entry.insert(0, v["key"])
        self.data_entry.delete(0, "end")
        self.data_entry.insert(0, v["plaintext"])
        self._log(
            f"Loaded {mode} FIPS-197 vector. Expected ciphertext: {v['ciphertext']}"
        )

    def _parse_hex(self, text, expected_bytes, field_name):
        text = text.strip().replace(" ", "")
        if len(text) != expected_bytes * 2:
            raise ValueError(
                f"{field_name}: expected {expected_bytes} bytes "
                f"({expected_bytes*2} hex chars), got {len(text)} chars"
            )
        try:
            return bytes.fromhex(text)
        except ValueError:
            raise ValueError(f"{field_name}: not valid hexadecimal")

    def _build_packet(self, mode_code, op_code, key_bytes, data_bytes):
        return bytes([START_BYTE, mode_code, op_code]) + key_bytes + data_bytes + bytes([END_BYTE])

    # ------------------------------------------------------------------
    # Send / receive
    # ------------------------------------------------------------------
    def _on_send_clicked(self):
        if serial is None:
            messagebox.showerror("Missing dependency", "pyserial is not installed.\nRun: pip install pyserial")
            return

        port = self.port_var.get()
        if not port:
            messagebox.showerror("No port selected", "Select a serial port first (click Refresh if empty).")
            return

        mode = self.mode_var.get()
        op = self.op_var.get()
        key_len = MODE_KEY_BYTES[mode]

        try:
            key_bytes = self._parse_hex(self.key_entry.get(), key_len, "Key")
            data_bytes = self._parse_hex(self.data_entry.get(), DATA_BYTES_LEN, "Data")
        except ValueError as e:
            messagebox.showerror("Invalid input", str(e))
            return

        mode_code = MODE_TO_CODE[mode]
        op_code = OP_TO_CODE[op]
        packet = self._build_packet(mode_code, op_code, key_bytes, data_bytes)

        self._log(f"Sending: mode={mode} op={op} packet={packet.hex()}")
        self.send_btn.configure(state="disabled")
        self.result_var.set("(waiting for response...)")

        # run the blocking serial I/O in a worker thread so the GUI doesn't freeze
        thread = threading.Thread(
            target=self._send_and_receive_worker, args=(port, packet), daemon=True
        )
        thread.start()

    def _send_and_receive_worker(self, port, packet):
        try:
            with serial.Serial(port, BAUD_RATE, timeout=SERIAL_TIMEOUT_S) as ser:
                ser.reset_input_buffer()
                ser.write(packet)
                response = ser.read(1 + DATA_BYTES_LEN + 1)  # start + 16 data + end

            if len(response) != (1 + DATA_BYTES_LEN + 1):
                self.result_queue.put(("error", f"No/incomplete response ({len(response)} bytes received). "
                                                 f"Check wiring, baud rate, and that the board is programmed."))
                return

            if response[0] != START_BYTE or response[-1] != END_BYTE:
                self.result_queue.put(("error", f"Framing error in response: {response.hex()}"))
                return

            result_bytes = response[1:1 + DATA_BYTES_LEN]
            self.result_queue.put(("ok", result_bytes.hex()))

        except serial.SerialException as e:
            self.result_queue.put(("error", f"Serial error: {e}"))
        except Exception as e:
            self.result_queue.put(("error", f"Unexpected error: {e}"))

    def _poll_queue(self):
        try:
            while True:
                status, payload = self.result_queue.get_nowait()
                if status == "ok":
                    self.result_var.set(payload)
                    self._log(f"Received result: {payload}")
                else:
                    self.result_var.set("(error -- see status log)")
                    self._log(f"ERROR: {payload}")
                self.send_btn.configure(state="normal")
        except queue.Empty:
            pass
        finally:
            self.root.after(100, self._poll_queue)


def main():
    root = tk.Tk()
    app = AESGuiApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
