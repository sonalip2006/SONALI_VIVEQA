# Day 09: 16-to-4 Encoder (One-Hot to Binary Converter)

## Overview
A 16-to-4 Encoder is a combinational logic circuit that translates a 16-bit one-hot input vector into a 4-bit binary output. It compresses the representation of sixteen distinct input lines down to just four output lines. 

*Note: While often referred to as a "Priority Encoder" in introductory materials, this specific implementation is a strict one-hot encoder. Because it relies on exact pattern matching, if multiple input bits are HIGH simultaneously, the output defaults to `0000` rather than prioritizing one active input over another.*

## Circuit Components
*   16-bit Input Bus
*   Combinational Logic Block (`case` statement)
*   4-bit Binary Output Bus

## Port Description
*   **`hex[15:0]`**: 16-bit one-hot input (representing a hexadecimal value position).
*   **`bin[3:0]`**: 4-bit binary output.

## Operational Flow
The encoder continuously evaluates the 16-bit input bus using pure combinational logic:
1.  **Read:** Monitor the `hex[15:0]` input.
2.  **Evaluate:** Compare the input against all 16 valid one-hot patterns.
3.  **Match:** If exactly one input bit is HIGH (a valid one-hot state), output the corresponding 4-bit binary value.
4.  **Default:** If the input is all zeros, or if multiple bits are HIGH (invalid state), output defaults to `0000`.

## Truth Table

| `hex[15:0]` Input | `bin[3:0]` Output |
|---|---|
| `0000 0000 0000 0001` | `0000` |
| `0000 0000 0000 0010` | `0001` |
| `0000 0000 0000 0100` | `0010` |
| `0000 0000 0000 1000` | `0011` |
| `0000 0000 0001 0000` | `0100` |
| `0000 0000 0010 0000` | `0101` |
| `0000 0000 0100 0000` | `0110` |
| `0000 0000 1000 0000` | `0111` |
| `0000 0001 0000 0000` | `1000` |
| `0000 0010 0000 0000` | `1001` |
| `0000 0100 0000 0000` | `1010` |
| `0000 1000 0000 0000` | `1011` |
| `0001 0000 0000 0000` | `1100` |
| `0010 0000 0000 0000` | `1101` |
| `0100 0000 0000 0000` | `1110` |
| `1000 0000 0000 0000` | `1111` |
| *Any other combination* | `0000` |

## Example Traces

**Valid Input 1:**
*   Input: `hex = 16'b0000_0000_0010_0000`
*   Output: `bin = 4'b0101`

**Valid Input 2:**
*   Input: `hex = 16'b0001_0000_0000_0000`
*   Output: `bin = 4'b1100`

**Invalid Input (Multiple bits HIGH):**
*   Input: `hex = 16'b0000_0000_0000_0011`
*   Output: `bin = 4'b0000` *(Default fallback)*

## Verilog Implementation Details

| Construct | Purpose |
|---|---|
| `always @(*)` | Defines the combinational logic block |
| `case` | Selects the binary output based on strict input matching |
| `default` | Catches invalid states (all zeros or multiple HIGH bits) |
| `reg` | Data type required for signals assigned within an `always` block |

## Project Evaluation

### Advantages
*   **Speed:** Purely combinational logic allows for immediate output updates without clock latency.
*   **Simplicity:** The `case` statement provides clean, readable, and easily verifiable code.
*   **Efficiency:** Maps cleanly to Look-Up Tables (LUTs) in FPGA architectures.

### Limitations
*   **Strict One-Hot Requirement:** Fails to provide meaningful data if multiple input lines assert simultaneously.
*   **Lack of Priority Logic:** True priority encoders use `if-else` or `casez` structures to resolve multi-bit collisions. This design simply rejects them.

## Summary
This module implements a 16-to-4 encoder in Verilog HDL utilizing a combinational `case` statement. It efficiently converts valid one-hot 16-bit inputs into equivalent 4-bit binary values. This project demonstrates the fundamentals of combinational multiplexing and default state handling in digital logic design.
