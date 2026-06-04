# 4. Threads and Warps

---

## 4.1. Threads
<div style="display: flex; align-items: center; justify-content: space-between; gap: 20px;">

<div style="flex: 1; text-align: justify;">
<div algin="justify">
Threads are the fundamental units of computation that are grouped into warps for parallel execution. A warp is a bundle of threads (typically 32 for NVIDIA, called wavefronts for AMD) that execute the same instruction simultaneously on a single Streaming Multiprocessor (SM). This "Single-Instruction, Multiple-Thread" (SIMT) model is how GPUs achieve high parallelism by having many threads process different data at the same time.
</div>
   
1. Each thread in a warp executes the same instruction.  
2. The PC is shared and maintains a thread mask for Writeback:  
   - **Write through:** At the time the write happens  
   - **Write back:** When the block is evicted  
3. Warp's execution is time-multiplexed at log steps.  
   EX:
     
     // To select one ready warp from 32 candidates:
    - Cycle 0: Check warps 0-15 vs 16-31 (which group has ready warps?)
    - Cycle 1: Check warps 0-7 vs 8-15 (within the winning group)
    - Cycle 2: Check warps 0-3 vs 4-7  
    -  Cycle 3: Check warps 0-1 vs 2-3
    -  Cycle 4: Select final warp (e.g., warp 2)

</div>
</div>
<div style="flex: 1; text-align: justify;">
This selection process takes log₂(32) = 5 steps!

Why This Matters for GPU Design?
- 32 warps → log₂(32) = 5 decision steps
- 64 warps → log₂(64) = 6 decision steps
- 128 warps → log₂(128) = 7 decision steps

The scheduling latency grows logarithmically with the number of warps, making it scalable.

</div>

---

## 4.2. Warps
<div style="display: flex; align-items: center; justify-content: space-between; gap: 25px;">

<div style="flex: 1; text-align: justify;">

Threads are grouped into warps, and all threads in a warp execute the same instruction at the same time( execute in parallel ). 
<div align="justify">
   
**Size** : The number of threads in a warp is hardware-dependent; for example, NVIDIA uses 32 threads per warp. means that 32 threads are grouped together and execute the same instruction simultaneously on its GPUs. 
This is the fundamental execution unit, known as SIMT (Single Instruction, Multiple Threads), which allows the GPU to process data in massive parallel chunks. Developers must align their work to this 32-thread warp size for optimal performance.
</div>
   
**Why 32 Became Common ?**

NVIDIA standardized on 32 because it provides a good balance:
-  Good parallelism (32-way)
-  Manageable control logic
-  Efficient memory access patterns
-  Reasonable register file size
-  Effective latency hiding
<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/jjrGj2y1/1.png" alt="Warp Masking Illustration" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;">Scheduling: Warps are the fundamental unit of scheduling on a GPU's Streaming Multiprocessor (SM).</p>
</div>

Each SM has one or more warp schedulers that constantly check which warps are ready to execute.

**On every clock cycle, each warp scheduler:**
   - 1.	Checks which warps are ready (not stalled waiting for data)
  -  2.	Selects one ready warp (using various policies)
 -   3.	Issues the next instruction from that warp to the execution units
<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/25fP5ynM/2.png" alt="Warp Masking Illustration" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;"></p>
</div>
<div align="justify">
Thread: The smallest unit of execution, defined by the programmer.
Grid: The highest level of the thread group hierarchy, which is a collection of thread blocks. 
Thread Blocks: A subset of threads within a grid. They are used to break down the overall workload into smaller, more manageable portions. 
Streaming Multiprocessors (SMs): These are general-purpose processors within the GPU that can execute several thread blocks in parallel. 
Execution Cores: Within each SM, there are execution cores such as Single Precision floating-point units (SPs) and Special Function Units (SFUs).
</div>

<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/Xv0Tvqw6/3.png" alt="Warp Masking Illustration" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;"></p>
</div>

**How Warps Work**
<div align="justify">
Lockstep execution: All threads in a warp execute the same instruction simultaneously, but each on a different piece of data. 
Scheduling: An SM's warp scheduler picks an active warp and issues one or more instructions to the execution units. 
Latency hiding: When a warp is waiting for data from memory, the SM can switch to another warp that is ready to execute, keeping the execution units busy. 
Partial warps: If a thread block has 100 threads and the warp size is 32, it will be divided into 3 full warps and 1 partial warp of 4 threads. This partial warp still requires the resources of a full warp, making it potentially inefficient. 
Optimizing with warps
</div>

</div>



</div>

| Architecture | Thread Group | Typical Size |
|---------------|---------------|----------------|
| NVIDIA | Warp | 32 threads |
| AMD | Wavefront | 64 threads |
| Intel | Subslice/Thread Group | varies |
| Others | SIMD Group | 8, 16, 32, etc. |

---

## 4.3. Thread Masking
<div style="display: flex; align-items: center; justify-content: space-between; gap: 0px;">
<div style="flex: 1; text-align: justify;">
<div align="justify">
In this section, we analyze how warp masking operates during the execution of the shown code segment. Warp masking is a fundamental mechanism in GPU architecture used to handle control flow divergence within a warp when threads follow different execution paths.
At statement A (t1 = tid * N), all threads execute in parallel. Each thread calculates its unique value of t1 based on its thread identifier (tid). Since all threads are executing the same instruction, the warp active mask at this point is set to all ones (e.g., 1111...1111), indicating that all threads are active and executing in lockstep. This represents the fully parallel execution phase, with no divergence present.
When execution reaches the conditional statement if (t3 != t4), divergence begins to occur. Threads within the same warp may evaluate this condition differently — some may take the true branch (leading to section B) while others take the false branch (leading to section F). At this point, the warp scheduler applies warp masking to control which threads are active for each branch.
</div>
</div>
<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/0NqLNjps/4.png" alt="Warp Masking Illustration" width="200"/>
  <p style="text-align:center; font-style:italic; color:gray;">Code Segment</p>
</div>
</div>

<div style="display: flex; align-items: center; justify-content: space-between; gap: 0px;">
<div style="flex: 1; text-align: justify;">
<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/jjrGj2zr/5.png" alt="Warp Masking Illustration" width="600"/>
  <p style="text-align:center; font-style:italic; color:gray;"></p>
</div>
   <div align="justify">
For threads that satisfy the condition (t3 != t4), the active mask enables only those threads, and all others are temporarily disabled (masked off). The warp executes the instructions inside branch B, such as t5 = data2[t2];, with only the active subset of threads.
During these divergent branches, the warp continues to issue one instruction per cycle, but only for the active lanes defined by the current mask. As a result, the GPU experiences reduced parallel efficiency, since not all threads contribute to computation simultaneously. The inactive threads remain stalled, waiting for reconvergence.
   </div>
   
</div>

</div>

---

## 4.4. Thread Divergence
<div style="display: flex; align-items: center; justify-content: space-between; gap: 25px;">

<div style="flex: 1; text-align: justify;">
<div align="justify">
The figure illustrates the warp masking behavior during the execution of the given code segment. Each block represents a program point (A–G) along with the active mask pattern of the threads within the warp. The binary mask (e.g., 1111, 1110, 0001) indicates which threads are active (1) and which are inactive (0) at each stage of execution.
At point A (t1 = tid * N), all threads execute in parallel, as shown by the active mask 1111. This represents full warp utilization, where every thread is active and performing computations simultaneously.
</div>
</div>

<div style="flex: 0 0 450px; text-align: center;">
  <img src="https://i.postimg.cc/25fP5y4m/6.png" alt="Thread Divergence Diagram" width="180"/>
  <p style="text-align:center; font-style:italic; color:gray;">Warp divergence and reconvergence illustration.</p>
</div>
</div>
<div style="display: flex; align-items: center; justify-content: space-between; gap: 25px;">

<div style="flex: 1; text-align: justify;">
However, divergence occurs at the conditional statement if (t3 != t4). At this point, the warp splits into two separate execution paths:

- The true branch, corresponding to block B, is taken by the threads that satisfy the condition (t3 != t4). These threads remain active, resulting in an active mask of 1110.

- The false branch, represented by block F, is taken by the remaining threads (0001 mask), which are active only during the execution of that path.

This divergence leads to inefficient use of threads because only a subset of the warp executes at a time while others are masked off. The SIMT (Single Instruction, Multiple Thread) model executes one branch at a time, so threads on the inactive path remain stalled, waiting for the warp to reconverge.

After completing both branches, the warp reconverges at point G, where the active mask returns to 1111. This marks the restoration of full parallelism and the continuation of efficient execution.

</div>
</div>

---

## 4.5. Synchronization Barrier
<div style="display: flex; align-items: center; justify-content: space-between; gap: 25px;">

<div style="flex: 1; text-align: justify;">
<div algin="justify">
Synchronization barriers are essential mechanisms that ensure all threads or processing units reach a specific point in the program before any of them continue execution. This prevents race conditions and guarantees that all required data is ready before subsequent computations begin.
</div>
<div style="flex: 0 0 300px; text-align: center;">
  <img src="https://i.postimg.cc/TPqB5xcz/7.png" alt="Warp Synchronization Barrier" width="800"/>
  <p style="text-align:center; font-style:italic; color:gray;"></p>  
</div>
   <div algin="justify">
At the beginning of execution, all threads within a warp are active and execute in parallel. The conditional statement if (threadIdx.x < 4) divides the warp into two distinct groups:
</div>
- Threads 0–3 satisfy the condition and execute the true branch containing statements A and B.
- Threads 4–7 do not satisfy the condition and instead execute the false branch containing statements X and Y.

**1. Divergence Phase**
<div algin="justify">
During execution of A and B, only threads 0–3 are active, while threads 4–7 are masked (inactive).
Once that path completes, the scheduler switches to the false branch, activating threads 4–7 for X and Y, while threads 0–3 remain masked off.
As shown in the figure, this results in sequential execution of both paths. Although logically parallel, the warp must execute both paths separately, leading to reduced parallel efficiency because only half of the threads are active at a time.
</div>
**2. Reconvergence Phase**
<div algin="justify">
After both branches have finished, the threads reconverge at the common instruction Z;.
At this point, the warp mask returns to all active threads (11111111), allowing full parallel execution to resume. Every thread executes statement Z; simultaneously, restoring full efficiency.
</div>

**3. Synchronization Phase**
<div algin="justify">
The final statement, __syncwarp(), performs warp-level synchronization. 
This ensures that all threads in the warp have completed execution up to this point before proceeding further. The synchronization phase, shown in yellow in the figure, indicates that the warp stalls until every thread reaches the same point of execution.

</div>
</div>



</div>

---

## 4.6. Warp Scheduling
<div style="display: flex; align-items: center; justify-content: space-between; gap: 25px;">

<div style="flex: 1; text-align: justify;">
<div algin="justify">

Each core in a GPU hosts contains many warps. A very interesting question is which order should these warps be scheduled in.

The Round-Robin arbiter operates on the principle of fair and cyclic scheduling. Each warp (or master) is assigned a unique identifier (ID), and the arbiter selects warps for execution in a First-In-First-Out (FIFO) manner. Once a warp is selected and granted access to execution resources, it is moved to the end of the scheduling queue, allowing other warps to be serviced in turn.
</div>

**In this mechanism:**
<div algin="justify">
   
- Each warp is treated equally and is given an equal opportunity to access computational resources.
-  After a warp completes its assigned execution slot, it is placed at the end of the queue, ensuring that it will not be selected again until all other warps have been serviced.
- If the same warp becomes ready again, it will be assigned the last priority in the scheduling sequence, maintaining the fairness of the arbitration process.
</div>
</div>
</div>

<table>
  <tr>
    <td style="text-align: justify; vertical-align: top; width: 60%;">
      <p>
        Imagine three children — <b>A</b>, <b>B</b>, and <b>C</b> — taking turns to go down a slide.
        This simple analogy helps visualize how a <b>Round-Robin arbiter</b> works to ensure fairness.
      </p>
      <ol>
        <li><b>Initial Order (Queue Start):</b> The children line up in the order <b>A → B → C</b>. The arbiter (like a teacher) allows <b>A</b> to slide first.</li>
        <li><b>After A’s Turn:</b> Once <b>A</b> finishes sliding, they go to the end of the line → <b>B → C → A</b>.</li>
        <li><b>After B’s Turn:</b> When <b>B</b> finishes, they also move to the end → <b>C → A → B</b>.</li>
        <li><b>Continuous Fairness:</b> Each child gets a turn equally — no one is skipped or repeated.</li>
      </ol>
    </td>
    <td style="text-align: center; vertical-align: top;">
      <img src="https://i.postimg.cc/25FgLYwp/8.png" alt="Round Robin Scheduling Example" width="350"/>
      <p style="text-align:center; font-style:italic; color:gray;">Round-Robin scheduling analogy.</p>
    </td>
  </tr>
</table>

