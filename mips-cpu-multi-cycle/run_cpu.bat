@echo off
echo Dang bien dich...
iverilog -o cpu_test.vvp -g2005-sv src/CPU.v src/Module/SignExt.v src/Module/ZeroExt.v src/Module/ALUOp.v src/Module/ExtMode.v src/Module/IsShift.v src/Module/ALU.v src/DataMemory.v src/InstMemory.v src/RegisterFile.v src/Module/MemoryOp.v src/Module/BranchOp.v src/Module/BranchOut.v src/Module/Forward.v src/Stage/InstFetch.v src/Stage/InstDecode.v src/Stage/Execute.v src/Stage/Memory.v src/Stage/WriteBack.v src/Cache.v src/DCache.v tests/CPU_tb.v
if %errorlevel% neq 0 (
    echo Bien dich that bai!
    exit /b %errorlevel%
)

echo Dang chay mo phong...
vvp cpu_test.vvp
echo Hoan tat. Ket qua duoc luu tai result.vcd
echo De xem song, chay: gtkwave result.vcd
