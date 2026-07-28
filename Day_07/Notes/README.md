# Day 07: Universal Flip-Flop Design (D, T, and JK)

## Overview
A flip-flop serves as the fundamental memory element in digital electronics, storing a single bit of data and updating its state synchronized to a clock edge. 

This project demonstrates a unified architecture where a single **D Flip-Flop** is configured to emulate three distinct flip-flop types:
*   D Flip-Flop
*   T Flip-Flop
*   JK Flip-Flop

The active mode is dynamically controlled via a **3:1 Multiplexer** using a 2-bit selector (`m`).

---

## Hardware Components
*   Base D Flip-Flop
*   Combinational Logic (for T and JK emulation)
*   3:1 Multiplexer
*   Synchronous Clock
*   Asynchronous Reset

---

## Port Configuration

### Inputs
*   **`clk`**: System clock signal.
*   **`reset`**: Asynchronous active-high reset.
*   **`a`**: Primary input (Functions as **D**, **T**, or **J** depending on the mode).
*   **`b`**: Secondary input (Functions as **K** for the JK mode).
*   **`m[1:0]`**: 2-bit mode selector.

### Outputs
*   **`q`**: The selected flip-flop's current state.
*   **`qb`**: The inverted state of `q`.

---

## Mode Selection

| `m[1:0]` | Active Mode |
|---|---|
| 00 | D Flip-Flop |
| 01 | T Flip-Flop |
| 10 | JK Flip-Flop |
| 11 | Default State |

---

## Flip-Flop Implementations

### 1. D Flip-Flop Mode (`m = 00`)
The input `a` is routed directly to the base flip-flop.

**Characteristic Equation:**
$$Q_{next} = D$$

**Truth Table:**

| D (`a`) | $Q_{next}$ |
|---|---|
| 0 | 0 |
| 1 | 1 |

### 2. T (Toggle) Flip-Flop Mode (`m = 01`)
The T flip-flop behavior is synthesized using the base D flip-flop and an XOR gate. The input `a` acts as the toggle trigger.

**Characteristic Equation:**
$$D = T \oplus Q$$

**Truth Table:**

| T (`a`) | Current Q | $Q_{next}$ | Behavior |
|---|---|---|---|
| 0 | 0 | 0 | Hold |
| 0 | 1 | 1 | Hold |
| 1 | 0 | 1 | Toggle |
| 1 | 1 | 0 | Toggle |

### 3. JK Flip-Flop Mode (`m = 10`)
The JK flip-flop is realized through combinational logic feeding into the base D flip-flop. Inputs `a` and `b` serve as J and K, respectively.

**Characteristic Equation:**
$$D = J\overline{Q} + \overline{K}Q$$

**Truth Table:**

| J (`a`) | K (`b`) | Current Q | $Q_{next}$ | Behavior |
|---|---|---|---|---|
| 0 | 0 | Q | Q | Hold |
| 0 | 1 | X | 0 | Reset |
| 1 | 0 | X | 1 | Set |
| 1 | 1 | 0 | 1 | Toggle |
| 1 | 1 | 1 | 0 | Toggle |

---

## Operational Flow

### Initialization (Reset)
When `reset = 1`, the internal state is cleared immediately, regardless of the clock or inputs:
*   `q = 0`
*   `qb = 1`

### Execution
When `reset = 0`, the multiplexer evaluates `m[1:0]` to route the correct boolean logic into the base D flip-flop. On every rising edge of `clk`, the flip-flop updates its state based on the selected characteristic equation.

---

## Example Traces

### D Flip-Flop Trace
| Clock Edge | D Input | Output Q |
|---|---|---|
| Reset | X | 0 |
| 1 | 1 | 1 |
| 2 | 0 | 0 |

### T Flip-Flop Trace
| Clock Edge | T Input | Output Q |
|---|---|---|
| Reset | X | 0 |
| 1 | 1 | 1 |
| 2 | 1 | 0 |
| 3 | 0 | 0 |

### JK Flip-Flop Trace
| Clock Edge | J | K | Output Q |
|---|---|---|---|
| Reset | X | X | 0 |
| 1 | 1 | 0 | 1 |
| 2 | 0 | 0 | 1 |
| 3 | 1 | 1 | 0 |
| 4 | 1 | 1 | 1 |

---

## Verilog Implementation Details

| Operator | Symbol | Usage in Design |
|---|---|---|
| **XOR** | `^` | Synthesizes the T flip-flop logic |
| **AND** | `&` | Used in the JK boolean equation |
| **OR** | `|` | Combines product terms for the JK equation |
| **NOT** | `~` | Inverts inputs and current state |
| **Non-blocking** | `<=` | Updates sequential register state |
| **Case** | `case` | Implements the 3:1 multiplexer logic |

---

## Project Evaluation

### Advantages
*   **Resource Efficiency:** Maximizes code reuse by relying on a single underlying memory element.
*   **Modular Architecture:** Easy to scale or adapt for complex state machines.
*   **Educational Value:** Clearly illustrates how complex sequential behaviors (T, JK) can be derived from combinational logic and a simple delay (D) element.

### Limitations
*   **Overhead:** Requires extra combinational logic gates to synthesize T and JK behaviors.
*   **Single Output:** Only one flip-flop mode can be active and observed at any given time.
*   **Unused State:** The `11` selector state is essentially a wasted configuration.

## Summary
This module successfully consolidates the functionality of D, T, and JK flip-flops into a single, multiplexer-driven Verilog design. By manipulating combinational logic equations before the D-input, the circuit dynamically adapts its behavior. This serves as an excellent demonstration of hardware reuse and sequential logic modeling for FPGA and ASIC design workflows.
