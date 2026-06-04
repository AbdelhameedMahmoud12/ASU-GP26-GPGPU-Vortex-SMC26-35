# 9. Debugging and Monitoring
Vortex GPGPU Debugging and Monitoring System
<div align ="justify">
<figure>
  <img src="https://i.postimg.cc/NjFNRf94/1.png" alt="Decode Stage Overview" width="700">
  
</figure>

## 9.1. What is Vortex?
Vortex is a specialized processor called a **GPGPU (General-Purpose Graphics Processing Unit)** designed to run thousands of computations simultaneously. Think of it like having 1,000 workers doing calculations in parallel instead of one worker doing them sequentially. This makes it incredibly fast for certain types of problems like scientific simulations, image processing, and machine learning.
However, debugging parallel processors is challenging when thousands of operations happen at once, finding which one went wrong is like finding a needle in a haystack. That's why Vortex includes a comprehensive debugging and monitoring system.

## 9.2. Why Do We Need Debugging Tools?
Imagine trying to fix a car engine while blindfolded you can't see what's happening inside. Debugging tools are like windows into the processor's "brain" that let developers:
- See what instructions are running and in what order
- Measure performance to find bottlenecks
- Track data movement through memory
- Diagnose errors when results are wrong
- Understand timing at the hardware level
Without these tools, developers would be guessing blindly.

## 9.3. How This Relates to our Project
When you're developing or modifying Vortex hardware, whether adding new features, optimizing the pipeline, or fixing bugs you must verify your changes work correctly before committing to synthesis and physical implementation. Here's why this debugging stack is critical:

Without these tools, you'd be flying blind changing hardware and hoping it works. **With them, you have confidence your modifications are correct before expensive synthesis runs.**

## 9.4. Real Example from our Workflow
Let's say you optimize Vortex's memory coalescer to improve bandwidth:
- **Performance counters** immediately show if cache hit rate improved
- **Instruction tracing** verifies load/store addresses are coalesced correctly
- **Hardware scope** confirms memory request signals have proper timing
- **Debug prints** show scheduler behavior with new logic
- **MMIO console** lets test kernels report their measured bandwidth
If counters show IPC drop instead of improving, you know immediately something is wrong before wasting hours on synthesis. You can trace the exact instructions causing slowdown, scope the hardware signals, and fix the bug in minutes instead of days.

## 9.5. Development -> Debug -> Verify -> Synthesize Workflow
1. You modify RTL code (add cache optimization, new instruction, pipeline change)
2. Compile with debug features enabled (DEBUG_LEVEL, SCOPE, etc.)
3. Run simulation/emulation with your test programs
4. Use debugging tools to verify:
    - Performance counters show expected IPC improvements
    - Instruction tracing confirms new logic executes correctly
    - Hardware scope proves timing relationships are valid
    - MMIO console outputs match expected results
5. Only after verification → proceed to synthesis, place-and-route, timing closure

## 9.6. The Five Layers of Debugging
Vortex provides five complementary debugging mechanisms, each offering a different view into the system:

### 9.6.1. Layer 1: Instruction Tracing

**What it does**
Records every instruction's journey through the processor pipeline, like a flight tracker following airplanes through airports.
<figure>
  <img src="https://i.postimg.cc/FzvWSy3h/2.png" alt="Decode Stage Overview" width="600">
  
</figure>

**Key features**
- Each instruction gets a unique ID (UUID) for tracking
- Captures which processor core, thread group (warp), and individual thread executed it
- Records timing, register values, and memory accesses
- Shows exactly where instructions get stuck (pipeline stalls)

**When to use it**
When you need to understand detailed execution flow or diagnose why specific instructions produce wrong results.

**Example**
If your program calculates wrong answers, instruction tracing shows exactly which calculation went wrong and what values were used.

**Power move**
Track UUID #12,345 through all pipeline stages to see where it got delayed or computed the wrong value.

### 9.6.2. Layer 2: Performance Counters


**What it does**
Automatically counts important events like a car's dashboard (speedometer, odometer, fuel gauge).

**Key metrics tracked**
- **IPC (Instructions Per Cycle)**: How many instructions complete per clock tick—the main efficiency measure
- **Cache hit rate**: Percentage of memory requests served from fast cache vs. slow main memory
- **Stalls**: Wasted cycles where no progress happens
- **Functional unit utilization**: How busy different hardware components are (math units, memory units, etc.)

**When to use it**
**Always start here!** Counters give you a quick health check with minimal overhead. Low IPC or poor cache performance immediately tells you where to investigate.

### 9.6.3. Layer 3: Debug Print System


**What it does**
Allows developers to insert messages throughout the code, controlled by verbosity levels.

**How it works**
- Set `DEBUG_LEVEL` when compiling (0 = silent, 3 = very verbose)
- Messages below your chosen level are completely removed (zero overhead)
- Higher levels show more detail (instruction fetch, pipeline stages, register values)

**When to use it**
When you need human-readable summaries of what's happening at key points, without drowning in detail.

**Example**
At `DEBUG_LEVEL=2`, you might see messages like "Fetched instruction at address 0x1000 for thread 5" helping you trace program flow.

**Power move**
Leave debug prints in code permanently. Enable only when debugging, disable for production  no penalty.

### 9.6.4. Layer 4: Hardware Scope System
**What it does**
Captures raw hardware signals the electrical "`wires`" inside the chip like an oscilloscope on a circuit board.

**Key features**
- Enabled with `SCOPE` compilation flag
- Uses special macros (`SCOPE_PROBE`) to mark signals to monitor
- Exports signal data to XML format
- Visualized as waveforms showing signal values over time

**When to use it**
For hardware-level debugging when software views don't reveal the problem timing issues, state machine bugs, or verifying hardware modifications.

**Example**
If instruction tracing shows correct behavior but results are still wrong, hardware scope might reveal that two signals arrive one clock cycle apart when they should be synchronized.

**Power move**
Probe your new cache controller's state machine, request/grant signals, and tag comparisons to verify correct operation cycle-by-cycle. This is slower but reveals timing issues invisible to software.

### 9.6.5. Layer 5: Memory-Mapped I/O Console
**What it does**
Provides a simple "`printf`" capability for programs running on Vortex without needing an operating system.

**How it works**
- Programs write characters to a special memory address (`IO_COUT_ADDR`)
- The emulator intercepts these writes and prints them to console
- Each thread has its own buffer to prevent garbled output

**When to use it**
For quick sanity checks in your programs printing "Thread 5 starting" or "Calculated result: 42".

**Example**
When debugging a parallel algorithm, each thread can print its status without requiring complex system calls or libraries.

**Power move**
Add MMIO prints at key points in your kernel to confirm it's executing as expected fast, deterministic, no system calls.

## 9.7. How These Tools Work Together: The Debugging Workflow
The key to effective debugging is using the right tool for the job. Here's the recommended approach:


**Step 1: Start High-Level (Performance Counters)**

Always check performance counters first. They give an instant health check:
- Is IPC reasonable? (Should be > 1.0 for parallel workloads)
- Is cache working? (Hit rate should be > 80%)
- Which pipeline stage shows the most stalls?
This takes seconds and immediately narrows down the problem area.

**Step 2: Add Selective Detail (Debug Prints + Tracing)**

Once you know the general problem (e.g., "memory bottleneck"), enable:
- Moderate debug level (`DEBUG_LEVEL=2`) for key events
- Instruction tracing for specific threads or time windows
Now you can see exactly which memory accesses are slow or which instructions cause stalls.

**Step 3: Deep Dive if Needed (Hardware Scope)**

If software-level debugging doesn't explain the issue, enable hardware scope to see raw signals. This is slower and more complex, so only use it when necessary.

**Step 4: Use MMIO Console Throughout**

Sprinkle MMIO console prints in your programs at key points as sanity checks. They're fast, simple, and help confirm your code is executing as expected.

## 9.8. Why This System is Powerful
These five layers provide complementary views at different abstraction levels:
- **Counters** = big picture in seconds
- **Prints** = human-readable milestones
- **Tracing** = instruction-level forensics
- **Scope** = hardware signal timing
- **MMIO Console** = program self-reporting
Together, they let you start broad, narrow down problems quickly, then drill into exact root causes. This hierarchical approach is essential for debugging complex parallel processors where millions of operations happen per second.

The system is **modular** enable only what you need, when you need it. This keeps overhead minimal while maintaining comprehensive visibility when debugging.

## 9.9. Practical Tips for Your Development Workflow
**For correctness debugging:**
- Add MMIO prints to verify inputs/outputs in your test kernel
- Enable `DEBUG_LEVEL=2` to see instruction flow
- Use instruction tracing to track specific wrong calculations

**For performance debugging:**
- Check performance counters (IPC, cache hit rate, stalls)
- Identify bottleneck (memory? compute? pipeline?)
- Use tracing to see detailed behavior of slow operations

**For hardware modifications:**
- Write targeted tests for your new feature
- Enable scope on relevant signals (cache state, scheduler grants, LSU queues)
- Visualize waveforms to confirm cycle-accurate behavior
- Cross-check with counters and tracing for consistency

**Build configuration:**
```
# Compile with -DDEBUG_LEVEL=N for verbosity
make DEBUG_LEVEL=3 # Verbose software debugging

# Add -DSCOPE for hardware signal capture
make SCOPE=1       # Enable hardware signal capture

```

## 9.10. Key Technical Terms Explained
| Term | Simple Explanation |
| :--- | :--- |
| Pipeline | Like an assembly line—instructions move through stages (fetch, decode, execute, memory, writeback) with multiple instructions in flight simultaneously |
| Core, Warp, Thread | Organizational hierarchy. A thread is one stream of instructions. A warp is a group of ~32 threads executing together. A core runs multiple warps |
| Cache | Fast memory that stores recently used data. Cache hits (data found in cache) are fast; cache misses (must fetch from slow main memory) are slow |
| Registers | Tiny, ultra-fast storage inside the processor holding data currently being worked on |
| Functional Units | Specialized hardware for different operations—ALU (arithmetic), LSU (memory access), FPU (decimal math) |
| RTL (Register-Transfer Level) | Hardware description language used to design processors—like a programming language but for circuits instead of algorithms |
| CSR (Control and Status Register) | Special registers that report status and control processor behavior, distinct from regular data registers |
| IPC | Instructions Per Cycle. Higher = better. Target 1.0+ for parallel workloads |
| UUID | Unique instruction ID for tracking |

## 9.11. Conclusion
 The Vortex GPGPU project represents a remarkable step toward open, flexible, and high-performance computing architectures that blend the programmability of RISC-V with the parallel power of modern GPUs. By developing a complete full-stack solution from ISA extensions and microarchitecture to software toolchain and FPGA deployment the project demonstrates how open-source hardware can rival proprietary GPU platforms in both performance and scalability. Through its hierarchical SIMT model, multi-stage pipelined execution, and comprehensive memory hierarchy, Vortex provides an efficient and modular foundation for executing massively parallel workloads.

The integration of custom RISC-V extensions such as Thread Mask Control (`TMC`), Warp Spawning (`WSPAWN`), and Control-Flow Divergence (`SPLIT/JOIN/BAR`) enables flexible thread management and efficient warp scheduling. These mechanisms, together with a robust scheduling and commit pipeline, allow Vortex to achieve high throughput and minimize latency, even under complex data-dependent workloads. The inclusion of multi-level caches, memory banking, and DRAM access optimization ensures that the architecture maintains balanced bandwidth utilization across all compute units.

On the software side, the LLVM-based compilation flow, OpenCL support through POCL, and unified runtime interface make Vortex not only a hardware innovation but also a developer-friendly platform. The toolchain’s ability to integrate with simulation environments, FPGA synthesis, and CI pipelines reinforces its practicality for academic research and industrial prototyping. Moreover, the comparative analysis of SIMD and SIMT execution within the report highlights the conceptual clarity of SIMT’s design: offering the simplicity of scalar programming with the efficiency of vectorized execution.

Ultimately, the Vortex GPGPU stands as an educational and technical milestone that bridges the gap between open-source design and high-performance parallel computing. It showcases how collaboration, modularity, and architectural transparency can foster innovation in GPU design. The project not only deepens understanding of GPU internals but also paves the way for future enhancements such as dynamic warp formation, tensor extensions, and AI-accelerated workloads confirming Vortex as a strong platform for next generation research and development.

</div>