# Day 06: Sequential Repeat Adder (149 Iterations)

## Overview
This project implements a sequential digital circuit that performs repeated addition of a single input value over multiple clock cycles. Rather than relying on a combinational hardware multiplier, this design utilizes a feedback accumulator to repeatedly add the input to itself.

In this architecture, an 8-bit input data stream is loaded into the output register during a reset state. The circuit then executes **149 consecutive additions** of this input value. An internal 8-bit counter tracks the iterations, and a `done` flag is asserted once the operation concludes.

## Hardware Components
*   8-bit Feedback Adder
*   8-bit Accumulator Register
*   8-bit Counter
*   Synchronous Clock (`clk`)
*   Asynchronous Reset (`rst`)
*   Completion Flag (`done`)

## Port Description

### Inputs
*   **`clk`**: System clock signal
*   **`rst`**: Asynchronous reset (Active high)
*   **`in_data [7:0]`**: 8-bit input data bus

### Outputs
*   **`out_data [7:0]`**: 8-bit accumulated output
*   **`done`**: High when 149 iterations are complete

## Operational Flow

### 1. Initialization (Reset State)
When `rst = 1`:
*   Accumulator (`out_data`) loads `in_data`.
*   Counter resets to `0`.
*   `done` flag is cleared to `0`.

### 2. Active Addition
When `rst = 0`, on every rising edge of the clock:
*   The accumulator updates: `out_data <= out_data + in_data`
*   The counter increments: `count <= count + 1`

### 3. Completion
Once `count` reaches **149**:
*   The addition operation halts.
*   The `done` signal asserts to `1`.

## Example Execution
Assuming an initial `in_data` of **8**:

| Clock Cycle | Counter | `out_data` |
|---|---|---|
| Reset | 0 | 8 |
| 1 | 1 | 16 |
| 2 | 2 | 24 |
| 3 | 3 | 32 |
| ... | ... | ... |
| 30 | 30 | 248 |
| 31 | 31 | 0 *(8-bit Overflow)* |
| 32 | 32 | 8 |

> **Note on Overflow:** Because `out_data` is an 8-bit register, its maximum value is 255. Any accumulation exceeding 255 will naturally wrap around to 0.

## Internal Registers

| Register | Function |
|---|---|
| **`out_data`** | Accumulates and stores the running sum |
| **`count`** | Tracks the number of completed clock cycles |
| **`done`** | Flags the completion of the 149th addition |

## Verilog Implementation Details

| Operator | Symbol | Purpose |
|---|---|---|
| **Addition** | `+` | Computes the sum of the accumulator and input |
| **Less Than** | `<` | Evaluates if the counter has reached 149 |
| **Non-blocking** | `<=` | Synchronously updates register states |

## Pros and Cons

### Advantages
*   **Hardware Efficiency:** Requires only one adder instead of a resource-heavy multiplier block.
*   **Simplicity:** Straightforward sequential logic and state management.
*   **FPGA Friendly:** Maps cleanly to standard FPGA logic elements.

### Limitations
*   **Latency:** Takes 149 clock cycles to yield a final valid result, making it slower than combinational multipliers.
*   **Width Constraints:** The 8-bit accumulator will overflow frequently for larger inputs unless the output width is expanded.

## Summary
This Verilog HDL design demonstrates a sequential arithmetic approach by using a feedback adder, an 8-bit accumulator, and a counter. It successfully adds an input value repeatedly for 149 clock cycles. This project serves as a foundational example of trading execution speed for hardware area efficiency in digital logic design.
