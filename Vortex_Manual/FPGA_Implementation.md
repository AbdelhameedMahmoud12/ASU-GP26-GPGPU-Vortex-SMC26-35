# 8. FPGA Implementation

## 8.1. FPGA Deployment Introduction
<div align="justify">
Imagine running a full-fledged GPU not on a silicon chip, but on a reconfigurable FPGA bending hardware to your will. That’s exactly what the Vortex GPGPU project makes possible. The “FPGA Deployment” section pulls back the curtain on how this open-source GPU core leaps from simulation to silicon, harnessing both Xilinx and Intel platforms through a clever mix of modular design, high-speed memory interfaces, and a unified runtime. Whether you’re a hardware hacker, FPGA designer, or systems researcher, this part of the Vortex story shows how flexible, vendor-agnostic GPU acceleration is no longer just theory — it’s running in the fabric.
</div>

## 8.2. Accelerator Function Unit (AFU) Overview
<div align="justify">
The AFU resembles the server of the whole functional deployment, and it is related to a specific vendor, whether Intel or Xilinx. But regardless the vendor, several elements are common across both Xilinx and Intel deployments and will be overviewed in the following table:
</div>

| **Component** | **Function / Description** | **Purpose in Deployment** |
| :--- | :--- | :--- |
| **Device Control Registers (DCR)** | Configuration and capability interface for the FPGA device. | Allows host software to query and control Vortex hardware features. |
| **Execution Control Signals** | `ap_start`, `ap_done`, `ap_ready`, `ap_idle`. | Manages start/stop handshakes between host and AFU for kernel execution. |
| **Reset Sequencer** | Multi-cycle reset delay mechanism. | Ensures stable initialization of the accelerator core and peripherals. |
| **Device Capability Registers** | Read-only registers reporting hardware capabilities (e.g., cores, memory banks). | Provides metadata for runtime and host code to adapt dynamically. |
| **ISA Capability Registers** | Report supported instruction set features or extensions. | Allows the host to tailor workloads to the available ISA set. |
| **Memory Bank Support** | Multi-bank memory with configurable interleaving. | Improves bandwidth and scalability across multiple memory interfaces. |
| **Unified Internal Bus Interface** | Common Vortex memory bus used before vendor adapters. | Maintains portability across FPGA vendors by isolating bus logic. |

## 8.3. Xilinx (XRT) Deployment Details
<div align="justify">
The Xilinx deployment of Vortex GPGPU uses the Xilinx Runtime (XRT) flow to generate a `.xclbin` binary, wrapping the core with an AXI4-Lite control and AXI4 memory interface through the `VX_afu_wrap` module. Key registers manage execution control, interrupts, and capability reporting, while multi-bank memory logic ensures efficient data access. Build parameters like target type, platform, and core count define the configuration. This design offers a clean, high-performance integration of the Vortex GPU core into Xilinx FPGA platforms with minimal vendor-specific overhead.
</div>

<figure>
  <img src="https://i.postimg.cc/QdTPKdW4/1.png" alt="Decode Stage Overview" width="700">
  
</figure>

## 8.4. Intel (OPAE) Deployment Details
<div align ="justify">
In the Intel FPGA deployment, Vortex GPGPU uses the Open Programmable Acceleration Engine (OPAE) flow to generate a `.gbs` bitstream. The `vortex_afu` module wraps the core using Intel’s CCI-P protocol for host communication and Avalon interfaces for memory access. Control and status are managed through MMIO registers, where commands and device capabilities are exposed to the host. Build parameters like target type, device family, and core count guide synthesis, while the memory logic supports burst transfers and multi-bank configurations for high throughput. This setup enables efficient, vendor-aligned integration of the Vortex GPU core within Intel FPGA platforms using OPAE’s standardized runtime environment.
</div>

<figure>
  <img src="https://i.postimg.cc/N0vn6v17/2.jpg" alt="Decode Stage Overview" width="700">
  
</figure>

## 8.5. Runtime Integration & Simulation Support
<div align = "justify">
The runtime system provides a unified API (`vortex`) for both XRT and OPAE paths, overlooking the vendor's differences:

- **XRT runtime**: Manages device opening, binary loading (`.xclbin`), memory buffer allocation per bank, writing DCR registers, starting execution (`ap_start`), polling for `ap_done`.

- **OPAE runtime**: Uses enumeration to find the AFU by UUID, MMIO writes/reads for configuration and commands, buffer allocation for host-device shared memory, issuing commands via MMIO.

- **Simulation support**: Both paths support simulation modes (via Verilator-based libraries) e.g., `xrtsim` for XRT, `opaesim` for OPAE. These allow cycle-accurate RTL simulation with a software-accessible interface.
This is important for development workflows as you can do full hardware emulation/simulation before deploying real FPGA hardware, and you can write host code once for both platforms via the unified API.
</div>

## 8.6. Conclusion
<div align = "justify">
The FPGA deployment of Vortex GPGPU demonstrates how a carefully modular and vendor-agnostic architecture can turn open-source GPU design into practical, reconfigurable hardware acceleration. By decoupling the core logic from vendor-specific wrappers, Vortex achieves true portability across Xilinx and Intel platforms without sacrificing performance. Its support for multi-bank memory, wide data paths, and unified runtime APIs highlights a forward-thinking design that balances flexibility with efficiency. Most importantly, this approach proves that high-performance GPU computation can be achieved on reprogrammable hardware—empowering researchers and developers to experiment, optimize, and extend GPU functionality in ways that fixed silicon cannot. In essence, Vortex’s FPGA deployment isn’t just an implementation step—it’s a blueprint for open, scalable, and future-ready GPU innovation.
</div>
