# Day 10: 8-Bit Arithmetic Logic Unit (ALU)

## Overview
An **Arithmetic Logic Unit (ALU)** is a core combinational digital circuit responsible for performing mathematical and bitwise operations. It serves as the computational backbone of processors and microcontrollers.

In this project, an 8-bit ALU is implemented. The design extracts two 4-bit operands (**A** and **B**) from hardware slide switches. A 16-button keypad acts as the operation selector, mapping each key to a distinct arithmetic or logical function. The final computed result is continuously driven to an 8-bit LED array.

---

## Hardware Configuration

### Port Mapping
*   **`push[7:4]`**: Operand A (4-bit input)
*   **`push[3:0]`**: Operand B (4-bit input)
*   **`key[15:0]`**: 16-bit One-Hot Operation Selector (Keypad)
*   **`led[7:0]`**: 8-bit Computed Output

### Operational Flow
Because the module uses purely combinational logic, the circuit requires no clock. 
1.  The hardware continuously reads the 8-bit switch bus and splits it into operands A and B.
2.  The combinational logic evaluates the active keypad button.
3.  The selected mathematical or logical transformation is applied to A and B.
4.  The output immediately updates on the LED array.

---

## Instruction Set (ALU Operations)

| Key Input | Operation | Verilog Expression |
| :--- | :--- | :--- |
| `key[0]` | Addition | `A + B` |
| `key[1]` | Subtraction | `A - B` |
| `key[2]` | Bitwise AND | `A & B` |
| `key[3]` | Bitwise OR | `A | B` |
| `key[4]` | Left Shift | `A << B` |
| `key[5]` | Right Shift | `A >> B` |
| `key[6]` | Bitwise XOR | `A ^ B` |
| `key[7]` | Bitwise NOT (A) | `~A` |
| `key[8]` | Multiplication | `A * B` |
| `key[9]` | Bitwise NOR | `~(A | B)` |
| `key[10]` | Bitwise NAND | `~(A & B)` |
| `key[11]` | Left Shift by 2 | `A << 2` |
| `key[12]` | Right Shift by 2 | `A >> 2` |
| `key[13]` | Bitwise XNOR | `~(A ^ B)` |
| `key[14]` | Increment A | `A + 1` |
| `key[15]` | Increment B | `B + 1` |

---

## Execution Example
Assume the input switches are set such that **A = 8** (`4'b1000`) and **B = 8** (`4'b1000`).
*(Note: Logical inversions like NOT, NOR, and NAND are calculated assuming the 4-bit operands are zero-extended to an 8-bit output bus).*

| Operation | Decimal Result | 8-Bit Binary (`led[7:0]`) |
| :--- | :--- | :--- |
| **Addition** | 16 | `0001_0000` |
| **Subtraction** | 0 | `0000_0000` |
| **AND** | 8 | `0000_1000` |
| **OR** | 8 | `0000_1000` |
| **XOR** | 0 | `0000_0000` |
| **NOT A** | 247 | `1111_0111` |
| **Multiplication** | 64 | `0100_0000` |
| **NOR** | 247 | `1111_0111` |
| **NAND** | 247 | `1111_0111` |
| **A << 2** | 32 | `0010_0000` |
| **A >> 2** | 2 | `0000_0010` |
| **XNOR** | 255 | `1111_1111` |
| **Increment A** | 9 | `0000_1001` |

---

## Verilog Implementation Details

| Construct | Usage in Design |
| :--- | :--- |
| `always @(*)` | Establishes the combinational logic block |
| `if-else` | Routes the correct operation based on the active key |
| `assign` | Continuously wires the switch bus to internal operand nets |
| `wire` | Defines the internal routing for Operands A and B |
| `reg` | Holds the ALU output value within the `always` block |

---

## Project Evaluation

### Advantages
*   **Versatility:** Consolidates 16 distinct operations into a single hardware block.
*   **Speed:** Purely combinational execution means the output is available with zero clock cycles of latency.
*   **Foundation Building:** Demonstrates the core logic structures used inside commercial CPUs and microcontrollers.

### Limitations
*   **Fixed Width:** Hardcoded to accept only 4-bit inputs and generate an 8-bit output.
*   **Single Issue:** Can only execute one instruction at a time based on keypad input.
*   **Collision Handling:** The `if-else` cascade inherently assigns priority to lower keys if multiple buttons are pressed simultaneously.

## Summary
This project successfully implements a 16-instruction Arithmetic Logic Unit using Verilog HDL. By routing slide switches as operands and keypad buttons as instruction selectors, the design provides an interactive, combinational demonstration of the fundamental arithmetic and logic operations that drive all modern digital computing.
