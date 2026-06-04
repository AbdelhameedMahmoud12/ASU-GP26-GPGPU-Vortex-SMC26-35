# 2. Architecture

## 2.1. Big Picture
<p align="justify">
Vortex is not a modification of an existing GPU architecture that was later adapted to RISC-V.  
Instead, Vortex was designed from the ground up as a <b>RISC-V-based GPGPU</b>.
</p>
<div align="center">
  <img src="https://i.postimg.cc/d09CH3nX/1.png" alt="Vortex Architecture Diagram" width="600">
  <p style="text-align:center; font-style:italic; color:gray;">
    Figure 1: The Architecture Works as Follows.
  </p>
</div>

<p align="justify">
Vortex extends the standard RISC-V ISA (<b>RV32IMAF/RV64IMAFD</b>) with custom instructions specifically designed for GPGPU execution.
</p>

- <b>RV32IMAF</b> → 32-bit RISC-V with Integer, Multiply/Divide, Atomics, and single-precision Float  
- <b>RV64IMAFD</b> → 64-bit RISC-V with Integer, Multiply/Divide, Atomics, single-precision Float, and Double-precision Float  

<p align="justify">
The key innovation is that <b>Vortex minimally extends RISC-V</b> rather than creating an entirely new ISA, making it sustainable within the open-source ecosystem.
</p>



<p align="justify">
These custom instructions enable SIMT execution and efficient thread-level control:
</p>

- **Thread Mask Control (TMC):** Controls active threads within a warp, using a TMC count to determine how many threads to activate simultaneously.  
- **Warp Spawning (WSPAWN):** Activates multiple warps for parallel execution.  
- **Control-Flow Divergence (SPLIT/JOIN/PRED):** Manages branch divergence during SIMT execution.  
- **Warp Synchronization (BAR):** Provides barrier synchronization across warps.  

<p align="justify">
These are implemented as <b>custom RISC-V instructions</b>, not as modifications of an existing GPU ISA.  
The design philosophy was to create a <b>full-stack open-source RISC-V GPGPU</b> from scratch — not to port an existing GPU architecture to RISC-V.
</p>

<p align="justify">
This approach minimizes ISA complexity while enabling GPGPU functionality, making it easier to integrate with the existing RISC-V toolchain and ecosystem.
</p>

## 2.2. Full Stack System 

<div align="center">
  <img src="https://i.postimg.cc/W47ZWzXb/2.png" alt="Full Stack Architecture Diagram" width="600">
  <p style="text-align:center; font-style:italic; color:gray;">
    Figure 2: Full Stack System Architecture.
  </p>
</div>

<p align="justify">
"Full stack" means the project provides a complete, end-to-end system spanning all layers from hardware to software:
</p>

---

### 1. Hardware Layer
<p align="justify">
• RTL implementation of the GPGPU cores, caches, and memory hierarchy  
• Configurable architecture parameters  
• Support for FPGA synthesis (Xilinx and Intel platforms)  
The hardware is organized hierarchically:  
• Multiple cores per socket (sharing L1 cache)  
• Multiple sockets per cluster (sharing L2 cache)  
• Multiple clusters (sharing L3 cache)
</p>

---

### 2. Simulation Layer
<p align="justify">
• Multiple simulation backends: SimX (C++ ISA simulator), RTLSim (Verilator-based), and FPGA simulators  
• All controlled by a unified driver interface
</p>

---

### 3. Software Toolchain
<p align="justify">
• Custom LLVM compiler backend (llvm-vortex) with RISC-V extensions  
• RISC-V GNU toolchain integration  
• POCL (Portable Computing Language) for OpenCL support
</p>

---

### 4. Runtime Layer
<p align="justify">
• Kernel runtime library providing low-level GPU functions  
• Host runtime libraries for different backends (simx, rtlsim, opae, xrt)  
• Unified API through stub runtime that dynamically loads the appropriate backend
</p>

---

### 5. Application Layer
<p align="justify">
• OpenCL 1.2 programming model support  
• Test suites and benchmarks  
This contrasts with many GPU projects that only provide one layer (e.g., just hardware RTL, or just a simulator), requiring you to integrate with external tools for the other layers.
</p>

## 2.3. Key Architectural Components
<p align="justify">
The Vortex architecture consists of several key components that work together to provide a scalable, high-performance RISC-V-based GPGPU system.
</p>

---

### 1. Command Processor → Host Driver & Runtime
<p align="justify">
The host-side driver and runtime system dispatch and manage kernels from the CPU.  
The runtime handles kernel launches and manages device resources.
</p>

---

### 2. Compute Units (CUs) → Cores
<p align="justify">
Vortex cores execute threads using RISC-V processors.  
Each core contains execution units (ALU, FPU, LSU, SFU) that process instructions.  
The architecture is hierarchical: <b>Clusters → Sockets → Cores</b>.
</p>

---

### 3. Warp Scheduler → VX_schedule Module
<p align="justify">
The <b>VX_schedule</b> module controls warp execution.  
It maintains active warps, stalled warps, thread masks, and program counters for each warp.  
The scheduler selects which warp executes next and manages warp control operations including spawn, join, and barrier synchronization.
</p>

---

### 4. Memory Hierarchy → Cache System + Local Memory
<p align="justify">
Vortex implements a multi-level cache hierarchy (<b>L1, L2, L3</b>) plus local shared memory.  
The memory system includes:
</p>

- L1 instruction and data caches per core  
- L2 cache shared within clusters  
- L3 cache at the top level  
- Local memory for fast shared access  
- Memory coalescing for bandwidth optimization  

---

### 5. Interconnect → Memory Arbiters & Crossbars
<p align="justify">
Memory arbiters connect cores to the cache hierarchy.  
The architecture uses <b>crossbars</b> for routing requests between cores and memory subsystems.
</p>

---

### 6. ISA → RISC-V + Custom Extensions
<p align="justify">
Vortex uses the <b>RISC-V base ISA (RV32IMAF/RV64IMAFD)</b> with custom SIMT extensions.  
Custom extensions include:
</p>

- Thread mask control (TMC)  
- Warp spawning (WSPAWN)  
- Control-flow divergence (SPLIT, JOIN, PRED)  
- Barrier synchronization (BAR)  

---

### 7. Host Interface → VX Device API
<p align="justify">
The runtime provides the host interface for CPU–GPU communication.  
It exposes device capabilities (threads, warps, cores, memory sizes) and manages memory transfers between host and device.
</p>

---

### 8. Software Stack → POCL + LLVM + Runtime
<p align="justify">
Vortex's software stack includes:
</p>

- OpenCL 1.2 support via POCL  
- LLVM-based compiler toolchain  
- Kernel runtime for thread/warp management  
- Device drivers for different backends (simx, RTL, FPGA)  

<p align="justify">
The Vortex architecture follows a hierarchical SIMT execution model with configurable parameters for cores, warps, and threads.  
The <b>6-stage pipeline</b> (<i>Schedule → Fetch → Decode → Issue → Execute → Commit</i>) processes instructions through specialized execution units.
</p>

## 2.4. Micro Architecture Details

<div align="justify">

The Vortex microarchitecture is a hierarchical design aimed at maximizing data throughput and minimizing latency through multi-level parallelism.

- **Processor:** The entire processing unit, which contains groups of clusters sharing the L3 cache.  
- **Cluster:** A group of sockets that share the L2 cache.  
- **Socket:** A physical unit that contains multiple cores sharing the L1 cache.  
- **Core:** An individual processing unit within a socket, which contains the execution pipeline.  

<p align="center">
  <img src="https://i.postimg.cc/hjPdHn5n/3.png" alt="Vortex Microarchitecture Overview" width="70%">
  <br><em>Figure 3 — Vortex Hierarchical Microarchitecture</em>
</p>

---

### 2.4.1. SIMT Execution Model

<p align="center">
  <img src="https://i.postimg.cc/JhQX60P8/4.png" alt="SIMT Execution Model" width="30%">
  <br><em>Figure 4 — SIMT (Single Instruction, Multiple Threads) Execution Model</em>
</p>

Vortex implements a **SIMT (Single Instruction, Multiple Threads)** execution model typical of GPGPUs.

- Threads grouped into warps (all threads in a warp execute the same instruction).  
- Warps time-multiplexed across a **6-stage pipeline** (Schedule → Fetch → Decode → Issue → Execute → Commit).  
- Hierarchical organization: **Cores → Sockets → Clusters.**  

| Level | Entity | Contains | Key Function |
|:------|:--------|:----------|:--------------|
| **System** | Clusters | Multiple clusters | Overall coordination and scaling |
| **Cluster** | Sockets | Multiple sockets | Mid-level organization and scheduling |
| **Socket** | Cores | Multiple cores | Compute execution and memory interface |
| **Core** | Warps | Multiple warps | SIMT execution unit |
| **Warp** | Threads | Multiple threads | Actual instruction execution |

Each level of hierarchy manages execution granularity and data flow:
- The **system** coordinates clusters.  
- Each **cluster** manages sockets and shared L2 resources.  
- Each **socket** executes workloads through multiple cores.  
- **Cores** execute **warps**, and warps contain multiple **threads**.

The architecture supports flexible configuration through parameters such as:
- Number of clusters in the system  
- Total number of cores in the system  
- Number of cores per socket  
- Number of warps per core  
- Number of threads per warp  

---

### 2.4.2. Pipelined Architecture

Vortex employs a **six-stage pipeline** with dedicated execution units.  
Instructions pass through the following pipeline stages:

<p align="center">
  <img src="https://i.postimg.cc/zfkhtv0B/5.png" alt="Pipeline Architecture" width="70%">
  <br><em>Figure 5 — Six-Stage Pipelined Architecture</em>
</p>

---

### 2.4.3. Schedule Stage

<p align="center">
  <img src="https://i.postimg.cc/k4XbkCp9/6.png" alt="Schedule Stage Overview" width="30%">
  <br><em>Figure 6 — Schedule Stage Overview</em>
</p>

The **Schedule Stage** is the first in the Vortex GPGPU pipeline.  
Its main function is to select which warp will execute next and to manage the state of all warps within a core.

Because GPUs rely on massive parallelism, multiple warps are maintained simultaneously, ensuring continuous instruction issue even when some warps stall waiting for memory or synchronization.

Key data structures maintained by the scheduler:
- **Active Warps Bitmap:** Indicates currently active warps.  
- **Stalled Warps Bitmap:** Tracks warps waiting for dependencies or barriers.  
- **Thread Masks:** Define active threads within each warp.  
- **Warp PCs:** Hold the program counter for each warp.  

This mechanism hides latency through **warp interleaving** — when one warp stalls, another executes.

#### 1. Warp Scheduler
Responsible for selecting the next warp to execute using a **round-robin policy** ensuring fairness and utilization.

**Stall Conditions:**
- Decode lock (buffer full).  
- Branch resolution pending.  
- Barrier synchronization.  
- Memory fence or resource dependency.  

**Warp Scheduling Output:**
- Selected warp ID  
- Active thread mask  
- Program counter (PC)  

Performance counters record ideal vs. stalled schedules to guide optimization.

---

#### 2. IPDOM Stack (Immediate Post-Dominator Stack)

<p align="center">
  <img src="https://i.postimg.cc/B6QKd3Vq/7.png" alt="IPDOM Stack Mechanism" width="30%">
  <br><em>Figure 7 — IPDOM Stack Handling Control Flow Divergence</em>
</p>

Used to manage **control flow divergence** in SIMT execution.

| Step | Action | IPDOM Stack Role |
|:-----|:--------|:----------------|
| 1 | Branch instruction encountered | Scheduler identifies divergent threads |
| 2 | Divergence detected | Push post-dominator PC & thread mask |
| 3 | Execute one path | Activate threads for current path |
| 4 | Path completes | Pop IPDOM entry, restore reconvergence PC |
| 5 | Reconverge | All threads rejoin at post-dominator instruction |

This mechanism ensures correct program flow while minimizing idle threads during divergence.

---

#### 3. Inflight Tracker

Monitors instructions currently in flight per warp to prevent hazards.

**Functions:**
- Track instruction completion status.  
- Flag busy warps as “inflight.”  
- Provide feedback to scheduler for hazard avoidance.  

Example:  
A warp issuing a memory instruction is marked “busy” until completion, preventing new issue.

---

#### 4. Control Flow Management

Manages special GPU operations:
- **Barriers:** Synchronize threads.  
- **WSPAWN:** Spawn new warps.  
- **Branch Control:** Update PCs after branch resolution.  

---

#### 5. Software Emulation (SIMX)

In the SIMX simulator, the **Core class** models scheduling logic:
- Round-robin selection with stall awareness.  
- Warp suspension during decode to emulate hardware latency.  

---

#### 6. Key Takeaways

- **Schedule Stage** hides latency via warp interleaving.  
- **IPDOM Stack** ensures correct reconvergence after divergence.  
- **Inflight Tracker** prevents resource conflicts.  
- **Warp Scheduler** balances execution dynamically.  
- Together, they maintain **high throughput and pipeline efficiency** in the SIMT architecture.

</div>
### 2.4.4. Fetch Stage  

<div align="justify">

The **Fetch Stage** is the second stage in the Vortex GPGPU’s 6-stage pipeline.  
Its primary purpose is to retrieve instructions from the **instruction cache (I-Cache)** and prepare them for the Decode Stage.  
This stage bridges the **Schedule Stage** (which decides which warp executes next) and the **Decode Stage** (which interprets fetched instructions).  

Since instruction fetches may take multiple cycles — especially when accessing caches — the Fetch stage is designed with **asynchronous handling**, **tag tracking**, and **elastic buffering** to maintain throughput.

</div>

#### 1. Input and Output Interfaces

<div align="justify">

**Input (from Schedule Stage)**  
The Fetch stage receives a scheduling packet containing:
- **Warp ID** – identifies the warp to fetch from  
- **Thread Mask** – indicates which threads are active  
- **Program Counter (PC)** – address of the next instruction  

**Output (to Decode Stage)**  
Once fetched, the Fetch stage outputs:
- **Warp ID**  
- **Active Thread Mask**  
- **Program Counter (PC)**  
- **Fetched Instruction Word (32-bit)**  
- **Unique Instruction Identifier**  

</div>

---

#### 2. Core Functionality

<div align="justify">

**1️⃣ Instruction Cache Request**  
When a valid scheduling command arrives, the Fetch stage forms an I-Cache request containing:
- PC address (4-byte aligned)  
- Tag (composite ID = warp ID + unique request ID)  

Elastic buffers temporarily store requests, decoupling timing and preventing stalls.  

**2️⃣ Tag Storage**  
To manage asynchronous cache responses, the Fetch stage uses a **dual-port RAM tag_store**:
- On request: writes PC and thread mask (indexed by warp ID).  
- On response: retrieves metadata using the tag.  

This ensures correct matching even if responses return out of order.  

**3️⃣ Instruction Cache Response Handling**  
When the I-Cache responds, the Fetch stage constructs a complete packet:
- UUID  
- Warp ID  
- Thread Mask  
- PC  
- 32-bit Instruction Word  

and forwards it to the Decode Stage.  

**4️⃣ Instruction Buffer Flow Control**  
When the I-Cache is disabled (e.g., in simulation), the Fetch stage manually tracks buffer occupancy per warp:
- Increment on new fetch  
- Decrement when Decode consumes an instruction  

This avoids deadlocks or buffer overflows, ensuring pipeline stability.  

</div>

---

#### 3. Software Emulation (SIMX Implementation)

<div align="justify">

In the **SIMX simulator**, the Fetch stage reproduces hardware behavior through:
- **MemReq structures** for requests  
- **Tag-based response tracking**  
- **Performance counters** for fetch latency and throughput  

The stage precisely models hardware flow control and pipeline timing in software.

</div>

---

#### 4. Key Takeaways  

<div align="justify">

- Fetch stage efficiently handles asynchronous cache operations.  
- Elastic buffering increases pipeline utilization.  
- Tag tracking ensures correct warp-instruction pairing.  
- Performance counters record fetch latency and stall cycles.  

</div>

---

### 2.4.5. Decode Stage  

<div align="justify">

The **Decode Stage** is the third stage of the Vortex pipeline.  
Its role is to interpret the **32-bit RISC-V instruction** fetched from memory and translate it into structured, hardware-ready signals.  
It performs:
- Instruction parsing  
- Operand extraction  
- Execution unit classification  
- Register encoding  
- Writeback control  
- Flow regulation through buffering  

This stage forms the logical core between instruction fetch and hardware execution.

</div>



#### 1. Input and Output Interfaces  

<div align="justify">

**Input (from Fetch Stage)**  
Receives:
- Warp ID  
- Thread Mask  
- Program Counter  
- 32-bit Instruction  
- UUID  

**Output (to Issue Stage)**  
Outputs:
- Decoded fields  
- Register indices  
- Operation and control info  

</div>

---

#### 2. Core Functionality  

<div align="justify">

**1️⃣ Instruction Parsing**  
Extracts fields from the 32-bit RISC-V instruction:

| Bits | Description |
|:----:|:-------------|
| [6:0] | Base operation type |
| [14:12] | Sub-operation selector |
| [31:25] | Extended decoding bits |
| [11:7] | Destination register |

---

**2️⃣ Execution Unit Type Determination**  
Each instruction maps to one of these **execution units**:

| Execution Unit | Description |
|:----------------|:------------|
| **ALU** | Integer arithmetic, logic, branches |
| **LSU** | Load/store and atomic operations |
| **FPU** | Floating-point operations |
| **SFU** | System/warp control ops |
| **TCU** | Tensor Compute Unit (optional) |

---

**3️⃣ Operation Type and Arguments**  
Determines:
- Immediate values  
- Function codes (`funct3`, `funct7`)  
- Special control flags  

All packed into a compact **decode_t** structure.

---

**4️⃣ Register Operand Encoding**  
Encodes register info and usage flags:
- Integer (`x`) and FP (`f`) registers  
- Usage flags (`use_x`) to skip unused operands  

Prevents unnecessary data dependencies.

---

**5️⃣ Writeback Control**  
Controls writeback enable (`wb`).  
Disables writes to **x0** (always zero).  

---

**6️⃣ Output Data Structure**

| Field | Description |
|:------|:-------------|
| UUID | Unique instruction ID |
| Warp ID | Warp executing the instruction |
| Thread Mask | Active threads |
| PC | Program counter |
| ex_type | Execution unit |
| op_type | Operation type |
| wb | Writeback flag |
| rs/rd | Register indices |

---

**7️⃣ Elastic Buffering**  
Smooths instruction flow between Decode and Issue:
- Absorbs timing differences  
- Prevents stalls  
- Maintains steady throughput  

---

**8️⃣ Scheduler Notification**  
Feedback to the warp scheduler:
- `valid` – decode completed  
- `wid` – warp ID  
- `unlock` – whether warp can resume  

Critical for warp-level synchronization and barrier handling.

</div>

---

#### 3. Software Emulation (SIMX Implementation)

<div align="justify">

In SIMX, the Decode stage:
- Checks buffer capacity  
- Pushes decoded ops to **ibuffer**  
- Releases or stalls warps dynamically  
- Tracks decode latency and correctness  

This mirrors real hardware behavior for performance validation.

</div>

---

#### 4. Key Takeaways  

<div align="justify">

- Decode bridges fetch and execution logic.  
- Handles both **RISC-V base (RV32I)** and **Vortex-specific** extensions.  
- Manages operand encoding, writeback, and scheduler feedback.  
- Maintains balanced pipeline flow and synchronization.  

</div>
### 2.4.6. Issue Stage  

<div align="justify">

The **Issue Stage** is responsible for selecting, preparing, and sending ready instructions from the decoded instruction stream to the execution units.  
It bridges the **Decode** and **Dispatch** stages and ensures that instructions are only issued when their operands are ready and no data hazards exist.

This stage consists of three major components:  
- **Instruction Buffer (IB)**  
- **Scoreboard**  
- **Operand Collector (OPC)**  

Together, these submodules handle instruction readiness, dependency tracking, and operand collection — ensuring smooth, hazard-free execution.

</div>



#### 1. Multi-Slot Issue Architecture  

<div align="justify">

The Issue stage in **Vortex** is *multi-slotted*, allowing multiple instructions to be issued in parallel.  
Each issue slot handles a specific subset of warps according to the following relation:

> **Per-Issue Warps = (Total Number of Warps) / (Issue Width)**

Each slot contains its own:
- Instruction Buffer  
- Scoreboard  
- Operand Collector (OPC)  

This **distributed issue architecture** enhances instruction-level parallelism (ILP) while isolating dependencies and stalls between warps.

</div>

---

#### 2. Instruction Buffer (IB)  

<div align="justify">

The **Instruction Buffer** stores decoded instructions per warp in dedicated queues.

| Parameter | Description |
|:----------|:-------------|
| **Depth** | Typically 2–8 instructions per warp |
| **Purpose** | Decouples Decode and Issue stages |
| **Effect** | Allows Decode to continue even when Issue stalls |

Each buffer entry stores all decoded instruction fields (except Warp ID, since each buffer is warp-specific).  
This buffering ensures continuous instruction flow and minimizes pipeline bubbles.

</div>

---

#### 3. Scoreboard  

<div align="justify">

The **Scoreboard** tracks register dependencies to prevent **Read-After-Write (RAW)** hazards.  
It maintains a bitmap of **in-use registers** for every warp.

**Dependency Check Logic:**
- If any **source register** (`rs1`, `rs2`, `rs3`) is marked as busy → stall.  
- If the **destination register** (`rd`) is pending a write → stall.  
- If no conflicts exist → instruction is ready to issue.

When an instruction issues:
- Its destination register bit is **set (reserved)**.  
- The bit is **cleared** during the Writeback stage.

This ensures correct data ordering and consistency across all warps.

</div>


#### 4. Operand Collector (OPC)  

<div align="justify">

The **Operand Collector (OPC)** fetches source operands from the **banked register file** once the Scoreboard marks the instruction as ready.  

Each issue slot includes multiple OPC units, and each unit can perform up to **three register reads per cycle** (`rs1`, `rs2`, `rs3`).  
Access is managed through a **crossbar interconnect** that resolves **bank conflicts** dynamically.  

Collected operands are sent to the **Dispatch Stage** via the operand interface.

When the number of threads per warp (`NUM_THREADS`) exceeds the **SIMD width**, the OPC processes the instruction across multiple cycles, using:
- **Start-of-Packet (SOP)** and  
- **End-of-Packet (EOP)** signals  

to maintain proper sequencing.

</div>

---

#### 5. Issue Selection Logic  

<div align="justify">

When multiple warps have ready instructions within a single issue slot:
- A **round-robin arbiter** selects one warp to issue next.  
This ensures fairness and prevents starvation.

The selected instruction is passed to the **Operand Collection** stage for execution preparation.

</div>

---

#### 6. Scheduler Notification  

<div align="justify">

Once operand collection begins, the Issue stage sends a **notification** back to the **Scheduler**.  
This includes:
- **Warp-in-Slot (WIS)** identifier  
- A signal during the **Start-of-Packet (SOP)** cycle  

This mechanism allows precise tracking of in-flight instructions and supports timing synchronization at the warp level.

</div>

---

#### 7. Performance Tracking  

<div align="justify">

The Issue Stage includes hardware **performance counters** to monitor and analyze pipeline bottlenecks.  
It tracks three primary stall types:

| Stall Type | Cause | Description |
|:------------|:------|:-------------|
| **Instruction Buffer Stall** | Buffer full | Decode cannot push new instructions |
| **Scoreboard Stall** | Dependency hazard | Operands not yet available |
| **Operand Stall** | OPC busy / bank conflict | Operand access delay |

These counters provide valuable insights for architectural optimization and performance tuning.

</div>

---

#### 8. Software Emulation (SIMX Simulator)  

<div align="justify">

In the **SIMX** functional simulator:
- The Issue stage is implemented within the **Core model**.  
- It checks the scoreboard for ready instructions.  
- Uses a round-robin arbiter for instruction selection.  
- Reserves the destination register upon issue.  
- Pushes ready instructions into the **Operand Collection** phase.  

This emulation mirrors the real hardware logic and provides cycle-accurate analysis of hazard behavior and performance.

</div>

---

#### 9. Key Takeaways  

<div align="justify">

- Hides register access latency.  
- Enables parallel issue through multi-slot design.  
- Ensures hazard-free execution using the Scoreboard.  
- Leverages OPC units for efficient operand fetching.  
- Provides stall metrics for fine-grained performance evaluation.  

→ **In essence**, the Issue Stage transforms decoded instructions into fully operand-ready micro-operations that can be dispatched efficiently to the execution units.

</div>
### 2.4.7. Execute Stage  

<div align="justify">

The **Execute Stage** is where actual computation takes place in the **Vortex GPGPU** pipeline.  
It receives ready-to-execute instructions from the **Issue Stage**, routes them to the appropriate **Functional Units (FUs)**, and manages their execution based on operation type and latency.

Each instruction is executed in parallel across multiple specialized units, allowing Vortex to sustain high throughput and efficiently utilize its **SIMD datapath**.

The Execute Stage is organized around a **dispatch layer** that connects the input interfaces (`dispatch_if`) from the Issue Stage to multiple FUs.  
Once execution is complete, results are sent via **commit interfaces (`commit_if`)** to the **Commit Stage**.

</div>


#### Core Responsibilities  

<div align="justify">

- Receive instructions from all issue slots (up to `ISSUE_WIDTH`).  
- Decode the **execution type (`ex_type`)** to determine the target functional unit.  
- Route the instruction and operands accordingly.  
- Manage multi-cycle execution and packet iteration for SIMD threads.  

This modular structure enables **parallel execution** of different instruction types across distinct functional units simultaneously.

</div>

---

#### Functional Units  

<div align="justify">

The Execute Stage integrates **five major Functional Units (FUs)**, each dedicated to a specific operation class.

</div>

---

##### 1. ALU Unit (Arithmetic Logic Unit)

<div align="justify">

Handles **integer arithmetic**, logic operations, and **branch control**.

**Operations:**
- Integer arithmetic: `add`, `sub`, `shift`
- Bitwise logic: `AND`, `OR`, `XOR`
- Multiply / divide operations (configurable latency)
- Branch evaluation and PC update (in coordination with the scheduler)

**Latency:**
- Arithmetic & logic: ≈ 2 cycles  
- Multiply: 2 cycles (configurable)  
- Divide: `XLEN + 2` cycles (~34 cycles for 32-bit operations)

**Key Role:**  
Implements the **core integer datapath** and branch resolution for each warp.

</div>

---

##### 2. LSU Unit (Load/Store Unit)

<div align="justify">

Handles **memory-related operations**, including loads, stores, and atomic operations.

**Operation Flow:**
1. Receives memory instructions from dispatch.  
2. Performs address calculation.  
3. Sends/receives data through the **data cache interface** (`lsu_mem_if`).  
4. Forwards results to the **Commit Stage**.

**Latency:**  
Variable — depends on cache hits/misses and memory hierarchy response.

**Key Role:**  
Ensures efficient data transfer and memory synchronization across threads.

</div>

---

##### 3. FPU Unit (Floating-Point Unit)

<div align="justify">

Handles **IEEE-754 floating-point operations** (if the FPU extension is enabled).

**Operations:**
- Floating-point arithmetic (add, subtract, multiply, divide)
- Square root and type conversions (e.g., `float ↔ int`)

**Latency:**  
4–10 cycles depending on operation complexity.

**Notes:**  
FPU operations run **in parallel** with integer ALU pipelines, maximizing utilization for **mixed workloads**.

</div>

---

##### 4. SFU Unit (Special Function Unit)

<div align="justify">

Handles **system-level and warp-control operations** such as:
- CSR (Control and Status Register) read/write  
- Warp control: `TMC`, `WSPAWN`, `SPLIT`, `JOIN`, `BARRIER`  
- Performance counter updates  

**Latency:** 2–4 cycles (depending on instruction type)

**Key Role:**  
Coordinates control flow and warp management, bridging the **scheduler** and **hardware control plane**.

</div>

---

##### 5. TCU Unit (Tensor Compute Unit)

<div align="justify">

Dedicated to **tensor operations** for AI and matrix-heavy workloads (if tensor extension is enabled).

**Operations:**
- Matrix multiply-accumulate (MAC) across SIMD lanes  
- Tensor arithmetic acceleration for ML inference  

**Latency:**  
Multi-cycle — dependent on tensor size and SIMD configuration.

</div>

---

#### Dispatch Mechanism  

<div align="justify">

The **Dispatch Layer** routes each instruction to the correct **Functional Unit (FU)** based on the decoded `ex_type` field.

**Process:**
1. Receives ready instructions from all Issue Slots.  
2. Decodes `ex_type` to identify the correct FU (ALU, LSU, FPU, SFU, TCU).  
3. Routes instruction and operand data to the FU’s input queue.  
4. For wide warps (`NUM_THREADS > SIMD_WIDTH`), manages **SIMD iteration** using **Start-of-Packet (SOP)** and **End-of-Packet (EOP)** signals.

This mechanism ensures **efficient utilization** of execution resources and correct synchronization among SIMD lanes.

</div>

---

#### Execution Flow  

<div align="justify">

**In Hardware:**  
- Each FU operates **independently**, processing its queue of incoming instructions.  
- Execution is **pipelined**, allowing multiple instructions to be in-flight simultaneously.  

**In the SIMX Simulator:**  
- The simulator replicates hardware dispatch behavior.  
- Checks if the dispatcher has output ready.  
- Pushes the instruction to the corresponding FU input queue.  
- Each FU simulates the correct latency (2–34 cycles).  
- Results are sent to the **Commit Stage** for synchronization and writeback.

</div>



#### Latency Characteristics  

| Functional Unit | Typical Latency (cycles) | Notes |
|:-----------------|:-------------------------:|:------|
| **ALU** | 2 | Add, logic, shifts |
| **Multiply** | 2 (configurable) | Integer multiplication |
| **Divide** | XLEN + 2 (~34 for 32-bit) | Iterative division |
| **FPU** | 4–10 | FP operations (variable) |
| **LSU** | Variable | Cache/memory-dependent |
| **SFU** | 2–4 | CSR / warp control ops |
| **TCU** | Multi-cycle | Tensor MAC operations |

---

#### Parallel Execution and Warp Distribution  

<div align="justify">

Each FU can handle **multiple warps simultaneously**, enabling **fine-grained multithreading**.  
Different instruction types execute **in parallel**:
- One warp executes a memory load (LSU)  
- Another performs a floating-point operation (FPU)  
- A third executes a branch (ALU)  

This **parallelism** allows high throughput and hides long-latency operations (e.g., memory or division) using **warp-level interleaving**.

</div>

---

#### Key Takeaways  

<div align="justify">

- Core computational engine of the Vortex pipeline.  
- Interfaces:
  - **Upstream:** Issue Stage via `dispatch_if`  
  - **Downstream:** Commit Stage via `commit_if`  
  - **Externally:** Memory and scheduler subsystems  
- Enables concurrent execution across multiple FUs.  
- Efficient SIMD management and configurable latency handling.  
- Maintains high throughput and performance through parallel operation of all functional units.  

→ **In summary**, the Execute Stage transforms operand-ready micro-operations into actual computations, delivering results to the Commit Stage for architectural state update.

</div>

The writeback interface carries a detailed set of signals:

| **Signal** | **Description** |
|-------------|----------------|
| **UUID** | Unique instruction identifier |
| **Warp-in-slot (WIS)** | Internal warp index used for scoreboard lookup |
| **SIMD ID (SID)** | Identifies the SIMD group |
| **Thread Mask** | Indicates which threads in the warp are active |
| **Program Counter (PC)** | Instruction address |
| **Destination Register (rd)** | Target register for the result |
| **Result Data** | Computed value to be written back |
| **SOP/EOP** | Start-of-packet / End-of-packet indicators |

Each writeback packet contains `SIMD_WIDTH` lanes of `XLEN`-bit results.  
Only the active lanes (based on the thread mask) are written.

After writeback:
- The **scoreboard** clears the “in-use” bit of the destination register.  
- The **register file** is updated with the result data.  
- Dependent instructions become ready for issue.

---

#### 🔹 Performance Counter Updates

The Commit Stage updates **instruction retirement statistics** via the **CSR interface**.

**Process:**
1. For each issue slot, a **population count (popcount)** determines the number of active threads that retired instructions.  
2. Per-slot counts are summed using a **reduction tree**.  
3. The final result updates the **`instret` (Instruction Retired)** counter.  

The counter value is accessible through CSR for software performance profiling.  
To improve timing, this logic is **pipelined across two stages**, enabling accurate per-cycle tracking of retired instructions.

---

#### 🔹 Warp Tracking and Scheduler Notification

The Commit Stage maintains a **bitmap** of warps that have committed instructions during each cycle.  
A warp is marked as committed when an instruction completes with the **EOP (End-of-Packet)** flag.

This information is:
- Aggregated across all issue slots  
- Pipelined for timing  
- Sent to the scheduler via `commit_sched_if.committed_warps`  

The Scheduler uses this signal to:
- Track in-flight instructions  
- Detect when a warp has completed execution  
- Re-enable instruction scheduling for that warp  

This forms the **feedback loop**:  
`Commit → Scheduler → Issue`, ensuring continuous, non-blocking execution.

---

#### 🔹 Software Emulation (SIMX Simulator)

In the **SIMX simulator**, the Commit Stage is modeled within the **Core module**.

For each issue slot:
- It checks the commit arbiter’s output queue.  
- When an instruction completes (`EOP = true`):  
  - Writes results using `writeback()`  
  - Releases destination register using `release()`  
  - Updates performance counters  
  - Notifies scheduler to mark the warp ready again  
  - Removes instruction from pending list  

This accurately models both **data flow** and **control synchronization** between pipeline stages.

---

#### 🔹 Debug Tracing

When **debugging mode** is enabled (`DBG_TRACE_PIPELINE`), the Commit Stage generates detailed trace logs for each committed instruction, including:

- Warp ID  
- SIMD ID  
- Program Counter  
- Execution Unit Type  
- Thread Mask  
- Writeback Flag  
- Destination Register (`rd`)  
- Result Data  

This provides **full pipeline visibility**, aiding in performance and hazard analysis.

---

#### ✅ Key Takeaways

- The **Commit Stage** ensures in-order retirement and architectural correctness.  
- It finalizes computation by:  
  - Writing back results  
  - Releasing dependencies  
  - Updating performance metrics  
  - Notifying the scheduler  
- Efficient arbitration and pipelining maintain **high throughput**.  
- Scheduler feedback sustains **warp interleaving** and pipeline utilization.

</div>
