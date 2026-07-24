# Day 03: 4-Bit Adder/Subtractor using Full Adders

## Overview
A **4-Bit Adder/Subtractor** is a combinational logic circuit capable of performing both addition and subtraction on two 4-bit binary numbers.

The architecture relies on a cascade of **four Full Adders**. A mode control signal, **$m$**, dictates the operation:
*   **$m = 0$** $\rightarrow$ Addition ($A + B$)
*   **$m = 1$** $\rightarrow$ Subtraction ($A - B$) via the **2's complement** method.

---

## Building Blocks

### 1. Half Adder
A Half Adder computes the sum of two 1-bit binary inputs, generating a **Sum** and a **Carry**.

**Boolean Equations:**
$$Sum = A \oplus B$$
$$Carry = A \cdot B$$

**Truth Table:**

| A | B | Sum | Carry |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 1 | 1 | 0 |
| 1 | 0 | 1 | 0 |
| 1 | 1 | 0 | 1 |

### 2. Full Adder
A Full Adder expands on the Half Adder by accommodating a third input: the Carry In ($C_{in}$). It is constructed hierarchically using two Half Adders and one OR gate.

**Boolean Equations:**
$$Sum = A \oplus B \oplus C_{in}$$
$$C_{out} = (A \cdot B) + (C_{in} \cdot (A \oplus B))$$

**Truth Table:**

| A | B | $C_{in}$ | Sum | $C_{out}$ |
|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 1 | 0 |
| 0 | 1 | 0 | 1 | 0 |
| 0 | 1 | 1 | 0 | 1 |
| 1 | 0 | 0 | 1 | 0 |
| 1 | 0 | 1 | 0 | 1 |
| 1 | 1 | 0 | 0 | 1 |
| 1 | 1 | 1 | 1 | 1 |

---

## 4-Bit Adder/Subtractor Architecture

The complete circuit chains four Full Adders together. The mode bit **$m$** controls the input sent to the $B$ terminals and sets the initial carry state.

### Operation Modes

| Mode ($m$) | Operation | Input routed to B | Initial $C_{in}$ | Final Output |
|:---:|---|---|:---:|---|
| **0** | Addition | $B$ (Unchanged) | 0 | $A + B$ |
| **1** | Subtraction | $\overline{B}$ (Complemented) | 1 | $A - B$ |

### Operational Flow

**Step 1: Input Conditioning (XOR Gate)**
Each bit of input $B$ is passed through an XOR gate alongside $m$:
$$B' = B \oplus m$$
*   If $m = 0$, $B' = B$
*   If $m = 1$, $B' = \overline{B}$

**Step 2: Carry Initialization**
The very first Full Adder receives $m$ directly as its $C_{in}$.
*   For addition ($m=0$), $C_{in} = 0$.
*   For subtraction ($m=1$), $C_{in} = 1$ (which completes the 2's complement logic: invert and add 1).

**Step 3: Ripple Propagation**
Each Full Adder computes its bitwise Sum and passes its $C_{out}$ to the $C_{in}$ of the next stage in the cascade.

**Step 4: Final Output**
The circuit yields a 4-bit Sum and a final Carry Out flag.

---

## Example Traces

| A | B | $m$ (Mode) | Operation | Result | $C_{out}$ |
|---|---|:---:|---|---|:---:|
| 0101 | 0011 | 0 | 5 + 3 | 1000 | 0 |
| 1001 | 0110 | 0 | 9 + 6 | 1111 | 0 |
| 1111 | 0001 | 0 | 15 + 1 | 0000 | 1 |
| 0101 | 0011 | 1 | 5 - 3 | 0010 | 1 |
| 1000 | 0010 | 1 | 8 - 2 | 0110 | 1 |
| 0110 | 0110 | 1 | 6 - 6 | 0000 | 1 |
| 0011 | 0101 | 1 | 3 - 5 | 1110 | 0 |

---

## Verilog Implementation Details

| Operator | Symbol | Hardware Context |
|---|:---:|---|
| **AND** | `&` | Carry generation |
| **OR** | `\|` | Carry combination |
| **XOR** | `^` | Sum generation & $B$ input toggling |
| **NOT** | `~` | 1's complement representation |

---

## Applications
*   Arithmetic Logic Units (ALUs)
*   Ripple Carry Adders
*   Microprocessor datapaths
*   FPGA and ASIC design
*   Embedded control systems

## Advantages
*   **Resource Efficiency:** Uses the exact same hardware blocks for both addition and subtraction.
*   **Scalability:** The cascading architecture easily scales up to 8-bit, 16-bit, or 32-bit widths.
*   **Modularity:** Employs hierarchical design by instantiating smaller sub-modules (Half Adders $\rightarrow$ Full Adders).

---

## Summary
This project models a 4-Bit Adder/Subtractor in Verilog HDL using a hierarchical design methodology. By combining Half Adders into Full Adders and cascading them, the circuit performs addition or 2's complement subtraction based on a single control bit. This modular architecture highlights a fundamental technique in digital logic design, making it highly efficient for FPGA synthesis.
