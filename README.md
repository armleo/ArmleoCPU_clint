# Deprecated
This repository is deprecated and outdated. This is now part of ArmleoCPU project, See https://github.com/armleo/ArmleoCPU/ for new versions.

# ArmleoCPU_clint

RISC-V CLINT implementation. Implements AXI4-Lite interface.


# State
Currently it implements basic RTL and test. Work in progress to meet all the specification

# Building and testing
You need working verilator (all deps included e.g. GCC, Linker, etc), make.

Just do:
```
cd testbench
make
```

This will auto test the core.

Structure:
```
src/ contains source code of core
    armleocpu_clint.v top module. Only paramter is HART_COUNT it should be in range of 1 .. 16
testbench/
    Makefile parameters to run verilator
    VerilatorSimulate.mk parameter controlled verilator runner
    sim_main.cpp Main testbench, look into source code it's pretty simple
```

# License
This core is licensed under standart copyright and is owned by Arman Avetisyan  
Feel free to read.  
No gurantee or warrany provided do anything on your own risk.  
