# 3. SIMT


<div align="justify">
Graphics Processing Units (GPUs) implement **SIMD (Single Instruction, Multiple Data)** architecture at the hardware level while presenting a **SIMT (Single Instruction, Multiple Threads)** programming model to developers.  
</div>
<div align="center">
  <img src="https://i.postimg.cc/wjkRXQzh/1.png"width="300">
  <p style="text-align:center; font-style:italic; color:gray;">
  </p>
</div>
<div align="justify">
This analysis examines the performance characteristics of these execution models through a canonical data-parallel workload — **element-wise vector addition**.  
The kernel performs independent operations per element: load A[i], load B[i], add, and store to C[i], repeated for *N* iterations.
</div>
<div align="justify">
This analysis demonstrates how **SIMT bridges the gap** between programmer-friendly threaded models and hardware-efficient SIMD execution, using vector addition as a canonical example.
</div>

---

## 3.1. Key Distinction: SIMD versus SIMT

<div align="justify">

There is an apparent tension between **SIMD** and **SIMT**: both expose data-level parallelism over independent data, but they differ in how they assign responsibility for managing parallelism between the programmer and hardware.

- **SIMD (Explicit Vectorization):**  
  The programmer (or compiler) writes code operating on vector registers and issues wide instructions that process multiple data elements at once. The programmer manages data alignment and packing.  
  Control flow requires explicit masking—when lanes diverge, masked execution can waste cycles.

- **SIMT (Implicit Vectorization):**  
  The programmer writes thread-scalar code, and the hardware groups threads into **warps** executing the same instruction stream in lockstep.  
  Each thread appears independent with private variables and program counters; divergence is managed automatically through masking and serialization.
</div>

---

## 3.2. Analytical Framework

<div align="justify">

This section establishes a first-order analytical comparison of **scalar**, **SIMD**, and **SIMT** execution paradigms under controlled assumptions.
</div>

| Parameter | Description | Value |
|------------|-------------|--------|
| N | Data Set Size | 32,768 elements |
| Memory Access Latency | Ideal L1 | 1 cycle per load/store |
| ALU Latency | Arithmetic Logic | 1 cycle per addition |
| Total Ops per Element | — | 4 cycles |
| SIMT Warp Width | Threads per Warp | 32 |
| SIMD Vector Width | Lanes per Vector | 8 |

---

## 3.3. Execution Methods

### 3.3.1. Scalar Execution (Baseline)


<div align="justify">
<div style="float: right; width: 300px; margin: 10px;">
  <img src="https://i.postimg.cc/QdqKQJDJ/2.jpg"  width="200">
  <p style="text-align:center; font-style:italic; color:gray;">
  </p>
</div>

The **scalar execution model** processes iterations sequentially through a single ALU. Each element undergoes complete processing before the next iteration, representing a classical **von Neumann model** with no data-level parallelism.
</div>

**Characteristics:**
- Parallelism: None  
- Data-Level Parallelism: None  
- Control Complexity: Minimal  
- Memory Access: Sequential  

**Performance:**
- Total Iterations: *N* = 32,768  
- Total Compute Cycles: *N × 4* = **131,072 cycles**  
- Total Memory Operations: *N × 3* = **98,304 ops**

---

### 3.3.2. SIMD Execution (CPU Contrast)


<div align="justify">

**SIMD** architecture employs vector registers and functional units that process multiple data elements concurrently. Iterations are grouped into vectors of width **V** (e.g., 8 lanes for AVX2). A single vector instruction applies to all lanes simultaneously.
</div>
<div align="center">
  <img src="https://i.postimg.cc/VkF0qWwR/3.jpg" width="600">
  <p style="text-align:center; font-style:italic; color:gray;">
  </p>
</div>

**Architectural Characteristics:**
- Parallelism: *V*-wide vector units  
- Instruction Stream: Single instruction per *V* elements  
- Memory: Contiguous and aligned  
- Control Logic: Minimal overhead  

**Execution Pattern:**
1. Load *V* elements of A and B  
2. Perform vector addition  
3. Store *V* results  

**Performance:**
- Total Chunks: *N / V* = 4,096  
- Total Compute Cycles: *Chunks × 4* = **16,384 cycles**  
- Total Memory Ops: *Chunks × 3* = **12,288 ops**

---

### 3.3.3. SIMT Execution (GPU Contrast)


<div align="justify">

The **SIMT** model organizes threads into **warps** (typically 32 threads) that execute instructions in lockstep.  
While presenting a scalar-threaded model, the hardware executes warps as SIMD groups.
</div>
<div align="center">
  <img src="https://i.postimg.cc/SxGY6f4d/4.jpg"  width="600">
  <p style="text-align:center; font-style:italic; color:gray;">
    Figure 1: The Architecture Works as Follows.
  </p>
</div>

**Architectural Characteristics:**
- Execution Unit: Warp (W threads)  
- Hardware: W-wide SIMD execution  
- Programmer’s View: Independent scalar threads  
- Memory: Thread-private with global access  

**Execution Flow:**
1. Each thread loads A[i], B[i]  
2. Warp performs addition  
3. Each thread stores to C[i]  
4. Active mask tracks divergence  

**Performance (Idealized):**
- Total Warps: *N / W* = 1,024  
- Total Compute Cycles: *Warps × 4* = **4,096 cycles**  
- Total Memory Ops: *Warps × 3* = **3,072 ops**

---

## 3.4. Performance Implications

<div align="justify">

Under idealized conditions with perfectly coalesced memory access and no control divergence:
- **SIMT achieves 32× speedup** over scalar execution  
- **SIMT achieves 4× speedup** over SIMD (with V=8)
</div>
<div align="justify">

However, SIMT's key benefit extends beyond raw performance metrics it combines high throughput with a simple, scalar programming model. Where SIMD requires developers to explicitly manage vector operations, handle data alignment constraints, and manually orchestrate parallel execution, SIMT presents each thread as an independent scalar entity. This abstraction dramatically simplifies parallel programming while achieving equivalent or superior hardware utilization
</div>
<div align="justify">

The architectural tradeoff lies in hardware complexity. SIMT requires sophisticated scheduling logic, divergence management mechanisms, and flexible memory systems to maintain the illusion of independent threads while executing warps as SIMD operations. This complexity manifests in larger chip area, higher power consumption, and additional scheduling overhead compared to simpler SIMD implementations.
</div>
<div align="justify">

For data-parallel workloads with regular memory access patterns and minimal control divergence, SIMT provides an optimal balance: the programming simplicity of threaded execution with the computational efficiency of wide SIMD hardware. This design philosophy underpins the success of GPU computing for applications ranging from graphics rendering to scientific computing and machine learning.
</div>