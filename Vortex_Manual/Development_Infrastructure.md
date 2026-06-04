# 7. Development Infrastructure
<div align="justify">

The development infrastructure supporting the Vortex General-Purpose GPU (GPGPU) is engineered as a comprehensive, full-stack open-source platform, supporting the specialized requirements of heterogeneous GPU architectural research atop the RISC-V Instruction Set Architecture (ISA). This ecosystem provides configurable hardware components, a tailored compiler stack, and a multi-modal simulation environment, all managed through highly automated scripts designed for rapid iteration and validation.

## 7.1. Build System and Environment Setup
The Vortex build system is based on a hierarchical Makefile structure, coordinated by a configure script, and explicitly configured here for the `RV64IMAFD` (64-bit architecture) target.

### 7.1.1. Step-by-Step Toolchain Installation for 64-bit
The core development environment is initialized using the following command sequence on supported Linux distributions (e.g., Ubuntu, Centos) or via WSL2/Ubuntu on Windows.

**1. Install Dependencies and Clone:**

```bash
# Install essential development dependencies
# (e.g., build-essential, python, uuid-dev)
sudo ./ci/install_dependencies.sh

# Explanation: The ci/install_dependencies.sh script
# automates the installation of critical system-level
# packages (like build-essential, python, git) required
# by the toolchain components.

# Clone Vortex codebase and change directory
# (--recursive ensures submodules are retrieved)
git clone --depth=1 --recursive \
  https://github.com/vortexgpgpu/vortex.git
cd vortex
```

**2. Configure the Build Environment for 64-bit:**

The configure script initializes the build environment, generates Makefiles (Makefile.in, config.mk.in), and defines key global variables.
```bash
# Create and enter the build directory
mkdir build
cd build
# Configure for 64-bit (RV64) ISA
../configure --xlen=64 --tooldir=$HOME/tools
# Explanation: The --xlen=64 flag explicitly sets the
# target architecture to 64-bit (RV64IMAFD).
# The --tooldir flag specifies the installation path
# ($HOME/tools) for customized toolchains.
```

**3. Install Specialized Toolchains:**

Vortex requires specialized versions of tools like `POCL, LLVM, RISCV-GNU-TOOLCHAIN, Verilator, Yosys, and Sv2v`. These are managed by automation scripts in the `ci` directory.


**4. Build Vortex Stack:**
The final step compiles the entire Vortex software stack using the hierarchical build system.
```bash
# Install all prebuilt toolchain components
./ci/toolchain_install.sh --all
# Explanation: This script downloads pre-built, version-locked
# toolchain binaries from the Vortex repository
# (ci/toolchain_prebuilt.sh.in) to ensure a
# reproducible build environment.

# Set environment variables (MUST be run for every new terminal session)
source ./ci/toolchain_env.sh
# Explanation: This script updates the PATH and sets variables
# (e.g., LLVM_VORTEX, RISCV_TOOLCHAIN_PATH)
# to make the compiler and simulation tools accessible to the Make system.
```

```bash
# Build the Vortex GPU software stack (runtime, drivers, simulators)
make -s
# Explanation: Compiles the entire Vortex stack (hw, sim, kernel,
# runtime, tests) using the Makefiles.
```

### 7.1.2. Configuration Management and Development Files
The build system utilizes several mechanisms to control the features and parameters.
- **Target Variables:**
  Parameters like `STARTUP_ADDR` can be set when invoking `make` to define specific execution details
  (e.g., `STARTUP_ADDR=0x80000000`).

- **`CONFIGS` Environment Variable:**
  This variable injects C-preprocessor macros (e.g., `-DGBAR_ENABLE`, `-DFPU_FPNEW`) used for conditional compilation in both software and RTL files (e.g., `hw/rtl/VX_config.vh`), enabling dynamic feature testing.

## 7.2. Software Toolchain and Kernel Compilation
The software toolchain handles kernel compilation and execution interface for the 64-bit Vortex core.

### 7.2.1. OpenCL and ISA Extension Strategy
Vortex supports OpenCL 1.2 by using the open-source PoCL / LLVM compiler stack. The key adaptations for the vortex architecture are as follows.
- **Modified PoCL Compiler Backend:** Configured to generate kernel programs compliant with the 64-bit Vortex ISA and its extensions.
- **Intrinsic Library:** Vortex implements minimal ISA extensions. The functionality of these custom instructions is exposed via an **Intrinsic Library** within the Vortex runtime, avoiding the need for deep, complex modifications to the core Clang/LLVM front-end, thus ensuring long-term sustainability.

### 7.2.2. Kernel Binary Generation (vxbin.py)
For bare-metal kernel execution (used in regression tests), the `kernel/scripts/vxbin.py` script converts the standard ELF binary output into a custom `.vxbin` format. This process ensures the runtime loader has critical address information by prepending an 8-byte minimum Virtual Memory Address (VMA) header and an 8-byte maximum VMA header (both 64-bit little-endian) to the raw binary data.

## 7.3. Testing Framework and Execution Control
The testing infrastructure utilizes a multi-level approach, from low-level unit testing to full system-level regression runs, unified by the `blackbox.sh` driver.

### 7.3.1. Unified Test Driver (ci/blackbox.sh)
The `ci/blackbox.sh` script serves as the universal testing interface, automatically reading configuration parameters, building the selected driver with appropriate options, and running the test application.

Execution Modes and Dynamic Configuration:
| **Driver** | **Type** | **Primary Use** | **Configuration Options Tested** |
| :--- | :--- | :--- | :--- |
| simx (Default) | C++ Architectural Simulator | Quick prototyping | `--app=vecadd, --cores=2` |
| rtlsim | RTL Simulation (Cycle-accurate) | Verification and timing analysis | `--driver=rtlsim, --l2cache` |
| fpga | Physical Hardware Driver | Real-world performance testing | `--driver=opae, --app=demo` |

**Dynamic Configuration Examples:**
The `ci/blackbox.sh` script maps command-line options directly to hardware configuration macros:
- **Core Scaling:**
  `./ci/blackbox.sh --cores=8 --warps=4 --threads=32 --app=sgemm`

- **Graphics Feature Test:**
  `CONFIGS="-DEXT_GFX_ENABLE" ./ci/blackbox.sh --app=draw3d --cores=2`
  (Enables optional graphics rasterizer/texture units.)

- **Accelerator Test (TCU):**
  `CONFIGS="-DTC_NUM=tcnum" ./ci/blackbox.sh --app=matmul --perf=1`
  (Sets Tensor Core count/size and enables performance monitoring for metrics collection.)

### 7.3.2. Comprehensive Test Suites (ci/regression.sh)
The `ci/regression.sh` script orchestrates the full suite of regression tests, validating complex GPGPU architectural features and configurations.

Test Suite Categories and Features:
| Test Suite | Invocation Flag | Key Architectural Features Tested |
| :--- | :--- | :--- |
| Unit Tests | `--unittest` | Low-level component tests. |
| ISA Tests | `--isa` | RISC-V compliance, FPU implementations (FPNEW, DPI, DSP). |
| Config. Tests | `--config1` | Validation of scalability (cores, warps, SIMD width). |
| Cache Tests | `--cache` | L1/L2/L3 enables, replacement policies. |
| Divergence Test | `--regression` | Validates complex control flow logic. |
| Debug Tests | `--debug` | Trace validation and unoptimized builds. |
| Tensor Tests | `--tensor` | Validation of the Tensor Core Unit (TCU). |
| Vector Tests | `--vector` | Validation of the RISC-V Vector Extension (V). |
| Synth. Tests | `--synthesis` | Validation of RTL synthesizability (Yosys). |

## 7.4. Hardware Synthesis and Continuous Integration

### 7.4.1. Commercial FPGA Synthesis Flow
To achieve peak performance (25.6 GFlops at 200 Mhz) and high core counts (up to 32 cores) , the project relies on commercial Electronic Design Automation (EDA) tools:
- **Xilinx Flow (Vivado):** Used for Xilinx FPGAs (Alveo, Versal). **Vivado Design Suite 2023.1** is employed for detailed area cost estimation on targets such as the Xilinx U50 FPGA.
- **Intel/Altera Flow (Quartus):** Required for Intel/Altera FPGAs (Stratix 10, Arria 10). These flows leverage specialized, hardened blocks (e.g., Floating-Point DSPs) within the FPGA fabric to maximize computational efficiency. The open-source path is maintained via Yosys and Sv2v for verifiability.

### 7.4.2. Continuous Integration (CI) Pipeline
The CI system, implemented via GitHub Actions (`.github/workflows/ci.yml`), ensures functional correctness across multiple configurations:
- **Setup:** Caches the toolchain binaries and installs dependencies.
- **Build:** Compiles the software and tests using a matrix for both `XLEN=32` and `XLEN=64`.
- **Tests:** Executes a comprehensive **52-job test matrix** in parallel, covering 2 OS versions, 2 architectures, and 13 distinct test suites (e.g., regression, cache, tensor). The CI pipeline includes active maintenance, such as adding **Ubuntu 24.04** support and implementing fixes for Yosys installation issues.

### 7.4.3. Docker Integration
Docker containers provide consistent, reproducible environments for development and testing, mirroring the CI setup.

**1. Production Container Setup (`miscs/docker/Dockerfile.prod`)**
The production container provides a fully pre-configured build environment. The Dockerfile sequence explicitly mirrors the installation steps required to build the Vortex stack:
```bash
FROM ubuntu:20.04
RUN git clone --depth=1 --recursive \
  https://github.com/vortexgpgpu/vortex.git /vortex
WORKDIR /vortex
RUN ./ci/install_dependencies.sh
RUN mkdir build && cd build && ../configure
RUN cd build && ./ci/toolchain_install.sh --all
RUN echo "source /vortex/build/ci/toolchain_env.sh" >> ~/.bashrc
WORKDIR /vortex/build
```
**Explanation:** This Dockerfile sequence clones the Vortex source, installs system packages, configures the build system (defaulting to 32-bit if no `--xlen` is passed to configure), installs the specialized toolchains, and permanently sets the toolchain environment variables in the container's bash profile (`~/.bashrc`). This configuration enables local testing that perfectly mirrors the CI environment.

**2. Development Container**
A minimal development container (`Dockerfile.dev`) is also provided for lightweight development work, where the local source code is typically mounted into the container at runtime.
</div>