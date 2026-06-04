# 6. Software Stack

<p align="justify">

The **software stack** is what allows programmers to write high-level GPU applications (like OpenCL kernels) that get compiled and executed on the Vortex hardware. It connects the **application layer**, **compiler**, **runtime**, and **hardware** layers into one coherent system.
</p>

---

## 6.1. Compilation Flow

<p align="justify">
When you write a GPU program (like in OpenCL or CUDA), you’re writing **two programs** inside the same file:
</p>

- **Host code** → runs on the **CPU (host processor)**  
- **Device code (kernel)** → runs on the **Vortex GPU (accelerator)**  

They work **together** — the host is like a manager that prepares data and sends “jobs” (kernels) to the GPU to execute in parallel.

**Step 1. Compilation Separation**

You compile the **host part** and the **device part** separately:

| Code Part | Compiler | Target | Output |
| ---------- | ---------- | ---------- | ---------- |
| Host code | Native GCC/Clang | Host CPU (e.g., x86 or ARM) | ELF executable |
| Device kernel | RISC-V GCC toolchain | Vortex GPU cores | `.vxbin` or `.elf` binary |

<p align="justify">

The **Vortex compiler toolchain** (`riscv32-unknown-elf-gcc`) compiles the kernel into RISC-V machine code.  
The **host compiler** (normal GCC) compiles your CPU-side code that uses **libvortex API calls**.
</p>

**Step 2. Host Program Loads the Kernel**

At runtime, the host program uses the **Vortex Runtime Library (`libvortex`)** to:
- Load the precompiled RISC-V kernel binary (`.vxbin`)
- Allocate memory on the GPU
- Transfer input data from host → GPU memory
- Instruct the GPU to start execution

**Step 3. GPU Executes the Kernel**

The **Vortex hardware** executes the kernel instructions on its **RISC-V SIMT cores**.  
Each core runs multiple **warps** → each warp runs multiple **threads**.  
All threads execute the same kernel but on **different data elements**.

**Step 4. Host Waits and Retrieves Results**

The host waits for completion (using synchronization in the runtime).  
Once GPU finishes, results are copied back to host memory.  
Host code continues execution normally.

<div align="center">
  <img src="https://i.postimg.cc/FsY14rbZ/2.png" alt="Host Compilation Flow" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;">Figure: Host Compilation Flow.</p>
</div>

---

## 6.2. GPU Compilation Flow

<p align="justify">
The GPU compilation process transforms kernel source code into executable binary for the Vortex GPU.  
It follows several key stages:
</p>

1. **Kernel Code Development**
   - Written in OpenCL, CUDA, or C++ using Vortex libraries.
2. **Front-end Compilation (PoCL)**
   - The kernel code is processed by a front-end compiler.
   - The front-end compiler generates Intermediate Representation (IR) from the kernel code, which can help improve optimization.
   - Uses built-in libraries for math functions.
3. **Back-end Compilation (LLVM)**
   - The IR is passed to a back-end compiler. 
   - The back-end compiler generates the kernel executable.
   - Uses Vortex Kernel Library for accessing runtime information and controlling program flow (e.g., vx spawn tasks & vx num threads).
   - Uses Vortex ISA which inlcudes custom RISC-V instructions for the Vortex GPGPU.

<div align="center">
  <img src="https://i.postimg.cc/YqvjHrN8/3.png" alt="GPU Compilation Flow" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;">Figure: GPU Compilation Flow.</p>
</div>

---
## 6.3. Vortex Execution Flow

<p align="justify">

The **Vortex Execution Flow** illustrates how the host software and GPU hardware interact to execute kernels efficiently.  
It defines a clear separation between control (on the host) and computation (on the GPU).
</p>
<div align="center">
  <img src="https://i.postimg.cc/qMNgTJcG/4.png" alt="GPU Compilation Flow" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;"></p>
</div>

---

### 1. Host Side

<p align="justify">
The host is responsible for managing memory, loading kernels, and sending commands to the GPU.  
The process follows these main stages:
</p>

**1. Command Creation**  
When a user program calls a runtime function such as `DeviceMemCopy()` or launches a kernel, a command is created.  
These commands include:
- Copying data between host and device memory.  
- Launching a kernel for execution.  
- Reading results from device memory.  

**2. Command Queue**  
Commands are placed into a **command queue**, ensuring they are executed in the correct order.

**3. Front-End Runtime Library**  
The **front-end runtime library** converts the user’s API calls into standardized command structures and pushes them into the queue.  
(Equivalent to the OpenCL or CUDA runtime layer.)

**4. Vortex Runtime Library**  
This library translates high-level commands into **Vortex-specific formats**.  
It prepares:
- Kernel binaries  
- Execution dimensions (grid/block sizes)  
- Memory addresses and arguments  

The runtime library acts as a software “driver” for the Vortex device.

**5. Vortex Host Interface**  
The **Vortex Host Interface** handles hardware communication.  
It packages commands and transfers them through the external bus (e.g., AXI or PCIe) to the GPU hardware.

---

### 2. Vortex GPU Side

<p align="justify">
On the GPU side, specialized interfaces handle command execution and data management.
</p>

**1. Vortex Accelerator Interface**  
The **accelerator interface** receives incoming commands and interprets them.  
It manages:
- Memory access and synchronization  
- Kernel loading  
- Coordination with GPU cores (Vortex Processor)  

It acts as the GPU’s **internal scheduler or dispatcher**.

**2. Vortex Processor**  
The **Vortex Processor** executes the kernel code using a massively parallel architecture based on the **SIMT (Single Instruction, Multiple Threads)** model.  
Once execution finishes:
- Results are written back to GPU memory.  
- The accelerator interface notifies the host that the command is complete.

---

### 3. Summary of Data Flow
Host → Runtime Library → Host Interface → External Bus → Accelerator Interface → GPU Processor → Result → Back to Host
<p align="justify">
This layered structure allows Vortex to separate software control from hardware execution, enabling scalability, portability, and efficient synchronization between CPU and GPU.
</p>

## 6.4. Vortex Parallel Programming Model

<p align="justify">
The **Vortex GPU** uses a <b>SIMT (Single Instruction, Multiple Threads)</b> execution model, similar to modern CUDA and OpenCL GPUs.  
This model enables thousands of lightweight threads to execute concurrently, providing high throughput for data-parallel workloads.
</p>

---

### 1. Threads and Warps

<p align="justify">
A <b>thread</b> is the smallest unit of execution.  
Each thread runs one instance of the kernel function with its own registers and local memory.
</p>

- **Warps** are groups of **32 threads** that execute the same instruction in lockstep under a single program counter (PC).  
- If threads within a warp take different branch paths (**divergence**), the warp serializes those branches and executes them separately — reducing throughput.

---

### 2. Thread Blocks

<p align="justify">
A <b>thread block</b> is a collection of threads that execute on the same Streaming Multiprocessor (SM).  
Threads in a block share on-chip <b>shared memory</b> and can synchronize using the barrier function <code>__syncthreads()</code>.
</p>

- Blocks can be 1D, 2D, or 3D, defined in code as:
  
  ```cpp
  dim3 blockDim(16, 16, 1);

- The block dimensions determine how data is partitioned and processed in parallel.
### 3. Grids
- All blocks launched for a kernel form a **grid**.  
- A grid may also be **1D, 2D, or 3D**:
  ```cpp
  dim3 gridDim(64, 64, 1);
- Each thread’s global index can be computed as:
  ```cpp
  int gid_x = blockIdx.x * blockDim.x + threadIdx.x;
- Independent blocks can be scheduled across multiple cores, allowing millions of threads to run in parallel.
### 4.  Kernel Launch and Streams
- Kernels are launched from the host using the syntax
  ```cpp
  kernel<<<gridDim, blockDim, sharedMemBytes, stream>>>(...);
- Streams allow multiple command queues to execute concurrently.
 This enables overlapping of computation and data transfer, improving overall throughput.
### 5. Synchronization and Communication
- <b>Intra-block synchronization : </b> Threads within the same block synchronize using shared memory and<code>__syncthreads()</code>.
</p>
- <b> Inter-block synchronization : </b> Achieved through multiple kernel launches or global memory operations since blocks cannot directly synchronize on-chip.
</p>
- <b>Best practice : </b>  minimize inter-block communication and global barriers to keep all GPU cores fully utilized.
</p>
