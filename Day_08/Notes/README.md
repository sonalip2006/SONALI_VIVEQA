# Day 08: Edge Detector

## Overview
An Edge Detector is a sequential digital circuit used to identify transitions in a signal. It captures when an input signal transitions from LOW to HIGH (positive edge), HIGH to LOW (negative edge), or any change in state (both edges). 

The design utilizes a D Flip-Flop to store the signal's previous state. This allows the circuit to compare the current input against the previous value in real-time using combinational logic.

---

## Circuit Architecture

### Components
*   **D Flip-Flop**: Stores the previous state ($q$).
*   **Combinational Logic**: Computes edge triggers.
*   **Clock (`clk`)**: Synchronous timing reference.
*   **Reset (`rst`)**: Asynchronous initialization.

### Port Description
| Port | Type | Description |
| :--- | :--- | :--- |
| `clk` | Input | System clock |
| `rst` | Input | Asynchronous active-high reset |
| `sig` | Input | Signal to be monitored |
| `pos_edge` | Output | High on rising edge ($0 \to 1$) |
| `neg_edge` | Output | High on falling edge ($1 \to 0$) |
| `both_edge` | Output | High on any transition |

---

## Logic Equations
The detection logic relies on comparing the current input (`sig`) with the stored previous state ($q$):

*   **Positive Edge**: $pos\_edge = sig \cdot \overline{q}$
*   **Negative Edge**: $neg\_edge = \overline{sig} \cdot q$
*   **Both Edges**: $both\_edge = pos\_edge + neg\_edge$

---

## Truth Table

| Previous ($q$) | Current (`sig`) | `pos_edge` | `neg_edge` | `both_edge` |
| :--- | :--- | :--- | :--- | :--- |
| 0 | 0 | 0 | 0 | 0 |
| 0 | 1 | 1 | 0 | 1 |
| 1 | 0 | 0 | 1 | 1 |
| 1 | 1 | 0 | 0 | 0 |

---

## Operational Flow

1.  **Initialization**: On `rst = 1`, the D Flip-Flop clears ($q = 0$), and all edge signals are driven low.
2.  **State Capture**: On every clock edge, the current `sig` is stored in the D Flip-Flop: $q \Leftarrow sig$.
3.  **Comparison**: The combinational logic compares the current `sig` with the newly stored $q$.
4.  **Generation**: If the state matches the defined edge conditions, the corresponding output bit pulses high for one clock cycle.

### Example Trace
| Cycle | `sig` | $q$ (Prev) | `pos_edge` | `neg_edge` | `both_edge` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Reset | 0 | 0 | 0 | 0 | 0 |
| 1 | 1 | 0 | 1 | 0 | 1 |
| 2 | 1 | 1 | 0 | 0 | 0 |
| 3 | 0 | 1 | 0 | 1 | 1 |
| 4 | 0 | 0 | 0 | 0 | 0 |
| 5 | 1 | 0 | 1 | 0 | 1 |

---

## Verilog Implementation Details

| Operator | Symbol | Purpose |
| :--- | :--- | :--- |
| **AND** | `&` | Detects specific edge conditions |
| **OR** | `|` | Combines positive and negative outputs |
| **NOT** | `~` | Inverts signals for logic comparisons |
| **Non-blocking** | `<=` | Updates sequential registers on clock edge |

---

## Applications
*   **Pulse Generation**: Creating triggers for state machines.
*   **Digital Communication**: Synchronizing data streams.
*   **Event Detection**: Interrupt handling in microcontrollers.
*   **FPGA/ASIC**: Clock gating and signal synchronization.

---

## Limitations
*   **Synchronous Reliance**: Edges are only detected on clock events. A signal that rises and falls entirely between two clock edges will be missed.
*   **Sampling Stability**: Requires a stable, jitter-free clock for reliable operation.

---

## Conclusion
This Edge Detector design leverages sequential storage (D Flip-Flop) and basic Boolean logic to identify signal transitions. It is a highly efficient, modular design suitable for standard FPGA and ASIC integration where reliable event detection is required.
