# Day 02: Full Adder Implementation via Two Half Adders

## Overview

A **Half Adder** is a foundational combinational logic circuit that computes the addition of two binary inputs (**$A$** and **$B$**), generating a **Sum** and a **Carry**. However, its inability to process a carry input from a previous stage limits its use in multi-bit addition operations.

A **Full Adder** overcomes this limitation by accepting three inputs (**$A$**, **$B$**, and **$C\_{in}$**) to produce a final **Sum** and **$C\_{out}$** (Carry Out).

This project demonstrates how a Full Adder can be constructed hierarchically using **two Half Adders and a single OR gate**, promoting modular, readable, and reusable hardware design.

\---

## Half Adder Fundamentals

The Half Adder computes the basic addition of two bits.

### Boolean Equations

$$Sum = A \\oplus B$$
$$Carry = A \\cdot B$$

### Truth Table

|$A$|$B$|Sum|Carry|
|-|-|-|-|
|0|0|0|0|
|0|1|1|0|
|1|0|1|0|
|1|1|0|1|

> \*\*Example:\*\* Adding $1 + 1$ results in a $Sum = 0$ and a $Carry = 1$.

\---

## Full Adder Architecture

A Full Adder computes the sum of three bits and is essential for cascading adders in multi-bit systems.

### Step-by-Step Operation

1. **First Stage (Half Adder 1):** Adds inputs $A$ and $B$.
$$Sum\_1 = A \\oplus B$$
$$Carry\_1 = A \\cdot B$$
2. **Second Stage (Half Adder 2):** Adds the intermediate sum ($Sum\_1$) to the carry input ($C\_{in}$).
$$Sum\_{final} = Sum\_1 \\oplus C\_{in}$$
$$Carry\_2 = Sum\_1 \\cdot C\_{in}$$
3. **Carry Logic (OR Gate):** The carry outputs from both Half Adders are combined. If either stage generates a carry, the final carry out is high.
$$C\_{out} = Carry\_1 + Carry\_2$$

### Final Boolean Equations

$$Sum = A \\oplus B \\oplus C\_{in}$$
$$C\_{out} = (A \\cdot B) + (C\_{in} \\cdot (A \\oplus B))$$

\---

## Full Adder Truth Table

|$A$|$B$|$C\_{in}$|Sum|$C\_{out}$|
|-|-|-|-|-|
|0|0|0|0|0|
|0|0|1|1|0|
|0|1|0|1|0|
|0|1|1|0|1|
|1|0|0|1|0|
|1|0|1|0|1|
|1|1|0|0|1|
|1|1|1|1|1|

\---

## Verilog Operators Used

When translating this logic into Verilog HDL, the following bitwise operators are utilized:

|Logic Gate|Mathematical Symbol|Verilog Operator|
|-|-|-|
|**AND**|$\\cdot$|`\&`|
|**OR**|$+$|`\|`|
|**XOR**|$\\oplus$|`^`|

\---

## Applications

* **Arithmetic Logic Units (ALUs):** The core computational block in microprocessors.
* **Ripple Carry Adders:** Chaining multiple Full Adders to add 8-bit, 16-bit, or 32-bit numbers.
* **Digital Signal Processing (DSP):** Used heavily in filtering and hardware mathematics.
* **ASIC \& FPGA Design:** Fundamental building blocks for custom digital systems.

\---

## Summary

This project successfully models a Full Adder using Verilog HDL by hierarchically instantiating two Half Adders. The simulation results confirm that the generated Sum and Carry Out strictly adhere to the expected truth table. This modular approach not only simplifies the code but also closely mirrors how complex digital circuits are physically synthesized from basic logic primitives.

