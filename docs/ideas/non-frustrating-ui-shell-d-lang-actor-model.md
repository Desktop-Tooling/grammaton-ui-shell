# **Project: Non-Frustrating UI Shell (D-Lang/Actor Model)**

## **1\. Core Goal**

Build a Windows/Linux UI shell that eliminates "stutter" and "hangs" by implementing an Erlang-style actor system in native D. Every UI component is an isolated, lightweight process (fiber) managed by a supervision tree. Erlang's runtime system (ERTS), specifically the BEAM virtual machine, is written in C. You can download it to provide a starting point for porting to D and tailoring for this project.

## **2\. Dependency & Toolchain Minimization**

* **Primary Toolchain:** Erlang (OTP 26+) and D-lang (DMD or LDC2).  
* **Native Reimplementation Strategy:** Replace third-party SDKs/libs with native D code using extern(C) for system-level syscalls.  
* **Static Linking:** Any unavoidable C/C++ libraries (e.g., Blend2D) must be statically linked to the D binary.

## **3\. Modular Project Structure**

To ensure reusability and clean separation of concerns, the system is divided into four distinct projects/libraries:

### **A. libbeam\_d (Core Actor Runtime)**

* **Purpose:** The foundational concurrency and fault-tolerance engine.  
* **Scope:** \* M:N Fiber Scheduler.  
  * Actor mailbox implementation (Lock-free MPSC).  
  * Supervision Tree logic (monitor/link/restart).  
  * Preemption logic via reduction counters.  
* **Constraints:** Must be 100% @nogc and independent of any UI or graphics code.

### **B. libglaze\_2d (Graphics Abstraction)**

* **Purpose:** A high-performance 2D rendering wrapper.  
* **Scope:**  
  * Native D bindings for Blend2D (extern(C)).  
  * Command batching and serialization logic.  
  * Text/Glyph caching system using native D font parsing.  
  * Per-Frame Arena allocator for geometry data.

### **C. libshell\_bridge (IPC & System Integration)**

* **Purpose:** OS and Erlang interoperability.  
* **Scope:**  
  * Native socket/Named Pipe implementation for Erlang communication.  
  * Raw extern(C) Win32/X11 bindings for window management and input.  
  * Binary serialization logic using CTFE.

### **D. ActorShell (Main Application)**

* **Purpose:** The final shell executable.  
* **Scope:** \* Composes the libraries to create the actual UI components.  
  * Implements specific shell logic (Start menu, taskbar, etc.).

## **4\. Memory Architecture**

* **Disable GC:** The runtime must be @nogc. Use core.memory.GC.disable().  
* **Manual Memory:** Use std.experimental.allocator for manual heap management.  
* **Per-Frame Arena:** All transient UI calculations happen in a pre-allocated arena that resets at VSync.  
* **Immutable Messaging:** Cross-actor data must be immutable for zero-copy passing.

## **5\. Native D Reimplementation Instructions**

* **Win32/X11:** Declare required functions directly via extern(C) in libshell\_bridge. Avoid heavy wrappers like arsd or dlang-win32.  
* **Serialization:** Reimplement JSON/Binary serialization in libshell\_bridge using CTFE.  
* **Input Handling:** Implement a native event loop in D that converts OS signals into Actor messages.

## **6\. Implementation Priorities for AI Agent**

1. **Phase 1 (libbeam\_d):** Construct the @nogc Fiber Scheduler and Actor mailbox system.  
2. **Phase 2 (libbeam\_d):** Implement the Supervisor logic (linking and restart strategies).  
3. **Phase 3 (libglaze\_2d):** Integrate Blend2D and build the command-batching renderer.  
4. **Phase 4 (libshell\_bridge):** Implement the IPC bridge and raw OS bindings.  
5. **Phase 5 (ActorShell):** Final composition of the shell UI.

## **7\. Performance Targets**

* **Target Frame Time:** \< 6.9ms (144Hz).  
* **Input Latency:** Sub-millisecond message delivery.  
* **Zero Jitter:** Non-blocking responsiveness regardless of I/O or background load.