# ASIC Design & Performance Optimization of Vortex GPGPU

[![ASIC Target](https://img.shields.io/badge/ASIC-Target-blue?style=for-the-badge)](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC)
[![Technology Node](https://img.shields.io/badge/Technology-FreePDK45nm-orange?style=for-the-badge)](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Synthesis)
[![Target Frequency](https://img.shields.io/badge/Target%20Frequency-250%20MHz-green?style=for-the-badge)](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Synthesis)
[![Toolchain](https://img.shields.io/badge/Toolchain-Synopsys%20Design%20Compiler-red?style=for-the-badge)](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Synthesis)

> [!NOTE]
> **Academic Mentorship by Dr. Hossam Hassan**
> 
> _“This project provides hands-on experience in full ASIC implementation using industry-standard tools and flows. You'll gain knowledge in synthesis, floorplanning, place & route, timing closure, and power analysis — all applied to a real GPGPU RTL core. I'm passionate about ASIC Design, RISC-V, VLSI, and GPGPU Architecture and look forward to mentoring students eager to build silicon-grade designs.”_

---

## 🎯 Project Objective

The goal of this project is to execute a complete ASIC design and physical performance optimization flow for the open-source **Vortex RISC-V GPGPU architecture**. The objective is to transition from a high-level SystemVerilog description to a silicon-ready physical layout, optimizing for Power, Performance, and Area (PPA) while targeting the **FreePDK45nm** technology node at a clock speed of **250 MHz**.

---

## 📊 Technical Specifications

| Parameter | Specification | Description |
| :--- | :--- | :--- |
| **GPGPU Core** | Vortex RISC-V GPGPU | SIMT execution model supporting warps/threads |
| **Technology PDK** | **FreePDK45nm** (Nangate 45nm) | Open-source standard cell library characterization |
| **Target Frequency**| **250 MHz** | Clock period constrained to **4.0 ns** |
| **Synthesis Tool** | Synopsys Design Compiler (DC) | Logic optimization, mapping, and report generation |
| **Physical Design**| Synopsys IC Compiler II (ICC2) | Floorplanning, CTS, and Routing |
| **Timing Signoff** | Synopsys PrimeTime (PT) | Post-route Static Timing Analysis (STA) |

---

## 🔍 Project Scope & Key Stages

### 1. RTL Analysis & Logic Synthesis
* Analyze GPGPU pipeline stages, memory modules, and control hierarchies.
* Clean up and adapt the RTL for ASIC synthesis (e.g., swapping out FPGA BRAMs for generic synthesizable RAMs).
* Perform logic synthesis using Synopsys Design Compiler, generating gate-level netlists and initial PPA reports.

### 2. Floorplanning & Physical Implementation
* Define core aspect ratio, cell utilization, and place standard cells.
* Design a robust Power Distribution Network (PDN) with power rings and rails.
* Perform Clock Tree Synthesis (CTS) to ensure clean clock distribution and minimal skew.
* Route layout and execute physical verification (DRC and LVS compliance).

### 3. Timing, Power, & Sign-off Analysis
* Run post-layout Static Timing Analysis (STA) under multiple corners.
* Perform detailed dynamic and leakage power analysis.
* Generate layout databases (DEF/GDSII) ready for signoff.

---

## 🧪 Verification Environment (UVM)

To ensure silicon-grade functionality, the Vortex GPGPU design is verified using a robust **Universal Verification Methodology (UVM)** framework. 

The UVM environment is structured to perform block-level verification on individual pipeline stages and full-chip verification on the top-level core. This includes:
* **Constrained-Random Test Generation:** Automated stimulus generation to maximize functional coverage.
* **Scoreboards & Reference Models:** Self-checking mechanisms to verify RTL correctness against the instruction set architecture (ISA) golden model.
* **Assertion-Based Verification (SVA):** Integration of SystemVerilog Assertions to catch design errors at interface boundaries.

---

## 📁 Repository Organization

The codebase is split into two primary segments to maintain modularity:

```
ASU_GP26_Vortex_ASIC/
├── RTL/                         # Unified synthesizable RTL source code
│   ├── VH/                      # Header and configuration files (*.vh, *.vi)
│   ├── interfaces/              # SystemVerilog interface definitions
│   ├── rtl/                     # Consolidated core design SV modules
│   └── *.sv                     # Top-level packages
│
└── Synthesis/                   # ASIC design compiler compilation setups
    ├── .gitignore               # Excludes large tool logs, netlists & caches
    ├── fetch/                   # Fetch stage synthesis environment
    ├── decode/                  # Decode stage synthesis environment
    ├── issue/                   # Issue stage synthesis environment
    ├── execute/                 # Execute stage synthesis environment
    ├── commit/                  # Commit stage synthesis environment
    ├── schedule/                # Schedule stage synthesis environment
    └── vortex/                  # Top-level Vortex GPGPU SoC environment
```

> [!IMPORTANT]
> **Unified RTL Architecture:** All SystemVerilog modules reside in `RTL/rtl/` and interfaces in `RTL/interfaces/`. The synthesis script for each pipeline stage is configured to read from these shared folders.

---

## 🚀 Running the Synthesis Flow

All target directories under `Synthesis/` are self-contained. The local `.gitignore` prevents large generated netlists (`*.v`), databases (`*.ddc`), delay files (`*.sdf`, `*.svf`), and local workspace caches (`work/`, `alib-52/`) from being tracked in the repository.

To run synthesis for any pipeline stage or the top-level SoC:

### 1. Library Dependencies
Ensure you have setup variables referencing standard cell libraries (`.db` format) in Nangate 45nm:
* `NangateOpenCellLibrary_tt1p1v25c.db`
* `NangateOpenCellLibrary_ff1p25vn40c.db`
* `NangateOpenCellLibrary_ss0p95v125c.db`

### 2. Execution Command
Navigate to the directory of the target stage under `Synthesis/` and run Design Compiler:
```bash
# Navigate to target stage directory (e.g. execute)
cd Synthesis/execute

# Run Design Compiler
dc_shell -f syn_script.tcl | tee syn_run.log
```

---

## 📑 Synthesis Modules Manifest

Each folder under `Synthesis/` compiles specific SystemVerilog files and holds its design constraints and reports:

| Folder | Top Module | Key RTL Source Files | Target Reports |
| :--- | :--- | :--- | :--- |
| **`fetch/`** | `VX_fetch` | `RTL/rtl/VX_fetch.sv` | Area, power, clocks, timing reports |
| **`decode/`** | `VX_decode` | `RTL/rtl/VX_decode.sv` | Area, power, clocks, timing reports |
| **`issue/`** | `VX_issue` | `RTL/rtl/VX_issue.sv`, `VX_issue_slice.sv` | Area, power, clocks, timing reports |
| **`execute/`** | `VX_execute` | `RTL/rtl/VX_execute.sv`, `VX_alu_unit.sv`, `VX_sfu_unit.sv` | Area, power, clocks, timing reports |
| **`commit/`** | `VX_commit` | `RTL/rtl/VX_commit.sv` | Area, power, clocks, timing reports |
| **`schedule/`** | `VX_schedule` | `RTL/rtl/VX_schedule.sv` | Area, power, clocks, timing reports |
| **`vortex/`** | `Vortex_axi` | `RTL/rtl/Vortex_axi.sv`, `Vortex.sv` | Full GPGPU system reports |

---

## 📅 Timeline (26-Week Implementation Plan)

| Phase | Weeks | Target Milestones |
| :--- | :--- | :--- |
| **Phase 1: Setup & Study** | Weeks 1–4 | Analyze GPGPU RTL, install tools, and configure FreePDK45nm cell libraries |
| **Phase 2: RTL Synthesis** | Weeks 5–8 | Formulate SDC timing constraints, clean up RTL, and run stage synthesis |
| **Phase 3: Floorplanning** | Weeks 9–12 | Define physical core parameters, floorplan layout, and place macros |
| **Phase 4: Place & Route** | Weeks 13–16| Perform standard cell placement, execute CTS, and route nets |
| **Phase 5: Signoff & Analysis**| Weeks 17–20| Run post-layout STA, estimate power grids, and perform DRC/LVS |
| **Phase 6: PPA Optimization** | Weeks 21–23| Resolve setup/hold timing violations, improve layout densities |
| **Phase 7: Final Delivery** | Weeks 24–26| Finalize technical reports, prepare GDSII layout, and present results |

---

## ⚠️ Potential Challenges & Mitigation

* **Timing Closure:** GPGPU designs contain tight paths around scheduler and thread controls. Highly tuned SDC constraints and layout optimization iterations are required to meet the 250 MHz target.
* **Large Layout Footprint:** Floorplanning the Vortex core requires balancing cell density and routing paths to prevent routing congestion.
* **CTS Skew Control:** Multi-clock structures in GPGPUs require dedicated Clock Tree Synthesis (CTS) configurations to keep clock skews at a minimum.

---

## 🎁 Project Deliverables

### 🛠️ Hardware & Backend Artifacts
* **Hardware Netlists:** Gate-level synthesized Verilog netlist, physical DEF layouts, and GDSII stream files.
* **Synthesis Scripts:** SDC constraints, Design Compiler compilation scripts, and ICC2 physical layout automation scripts.
* **PPA Reports:** Area utilization sheets, dynamic/static leakage power estimations, and timing analysis signoffs.

### 🎓 Academic Deliverables (Discussions & Defenses)
The project documentation is organized by academic phases under the `Deliverables/` folder:
* **Phase 1 (Term 1 Defense):**
  * **[Initial Thesis Document](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Deliverables/Phase-1/An%20Open-Source%20Vortex%20GPGPU%20Architecture_Intial_Thesis.pdf)** (First-term defense thesis)
  * **[Initial Presentation Slides](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Deliverables/Phase-1/An%20Open-Source%20Vortex%20GPGPU%20Architecture_Intial_Presentation.pptx)** (Defense presentation PowerPoint)
  * **[Project Poster](file:///D:/5_th_year/GPGPU/GP_GPU/ASU_GP26_Vortex_ASIC/Deliverables/Phase-1/An%20Open-Source%20RISC-V%20GPGPU%20Architecture_poster.pdf)** (Academic display poster)
* **Phase 2 (Term 2 Defense - In Progress):**
  * **Thesis/Report (LaTeX Source):** The final report source code, hosted under `Deliverables/Phase-2/`.
  * **Final Presentation & PDF:** Under development.

---

## 👥 Contributors

This project is a collaborative effort. See the full list of team members and academic supervisors in [CONTRIBUTORS.md](CONTRIBUTORS.md).
