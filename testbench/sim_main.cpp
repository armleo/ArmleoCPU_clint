#include <verilated.h>
#include <verilated_vcd_c.h>
#include <Varmleocpu_clint.h>
#include <iostream>

vluint64_t simulation_time = 0;
VerilatedVcdC	*m_trace;
bool trace = 1;
Varmleocpu_clint* armleocpu_clint;

using namespace std;

double sc_time_stamp() {
    return simulation_time;  // Note does conversion to real, to match SystemC
}
void dump_step() {
    simulation_time++;
    if(trace) m_trace->dump(simulation_time);
}
void update() {
    armleocpu_clint->eval();
    dump_step();
}

void posedge() {
    armleocpu_clint->clk = 1;
    update();
    update();
}

void till_user_update() {
    armleocpu_clint->clk = 0;
    update();
}
void after_user_update() {
    update();
}


void next_cycle() {
    after_user_update();

    posedge();
    till_user_update();
    memory_update();
    armleocpu_clint->eval();
}


void axi_write(uint32_t address, uint32_t data) {

}

uint32_t axi_read(uint32_t address) {

}




string testname;
int testnum;

void test_begin(int num, string tn) {
    testname = tn;
    testnum = num;
    cout << testnum << " - " << testname << endl;
}

void test_end() {
    next_cycle();
    cout << testnum << " - " << testname << " DONE" << endl;
}


int main(int argc, char** argv, char** env) {
    cout << "Test started" << endl;
    // This is a more complicated example, please also see the simpler examples/make_hello_c.

    // Prevent unused variable warnings
    if (0 && argc && argv && env) {}

    // Set debug level, 0 is off, 9 is highest presently used
    // May be overridden by commandArgs
    Verilated::debug(0);

    // Randomization reset policy
    // May be overridden by commandArgs
    Verilated::randReset(2);

    // Verilator must compute traced signals
    Verilated::traceEverOn(true);

    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    // This needs to be called before you create any model
    Verilated::commandArgs(argc, argv);

    // Create logs/ directory in case we have traces to put under it
    Verilated::mkdir("logs");

    // Construct the Verilated model, from Varmleocpu_clint.h generated from Verilating "armleocpu_clint.v"
    armleocpu_clint = new Varmleocpu_clint;  // Or use a const unique_ptr, or the VL_UNIQUE_PTR wrapper
    m_trace = new VerilatedVcdC;
    armleocpu_clint->trace(m_trace, 99);
    m_trace->open("vcd_dump.vcd");

    armleocpu_clint->rst_n = 0;
    till_user_update();
    armleocpu_clint->rst_n = 0;
    next_cycle();
    armleocpu_clint->rst_n = 1;

    uint32_t MSIP_OFFSET = 0;
    uint32_t MTIMECMP_OFFSET = 0x4000;
    uint32_t MTIME_OFFSET = 0xBFF8;

    uint8_t harts = 8;

    AXI_WRITER axi_writer(
        
    );

    
    try {
        
        for(int i = 0; i < harts; ++i) {

            axi_writer->write32(axi_writer, MSIP_OFFSET + hart_id, 0x1);

            if(armleocpu_clint->hart_swi & (1 << i)) {
                cout << "Test for hart: " << i << "correct hart_swi" << endl;
            }

            uint64_t mtime;
            bool success = 1;
            axi_reader->read32(MTIME_OFFSET, &mtime);
            axi_writer->write32(MTIMECMP_OFFSET + i, mtime + 4);

            for(int j = 0; j < 6; ++j) {
                if(armleocpu_clint->hart_timeri & (1 << i)) {
                    cout << "MTIMECMP test done for hart: " << i << endl;
                    success = true;
                    break;
                }
            }
            if(!success){
                cout << "Failed test for MTIMECMP" << endl;
                throw "Failed test for MTIMECMP";
            }
        }


        cout << "MMU Tests done" << endl;

    } catch(exception e) {
        cout << e.what();
        next_cycle();
        next_cycle();
        
    }
    armleocpu_clint->final();
    if (m_trace) {
        m_trace->close();
        m_trace = NULL;
    }
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif

    // Destroy model
    delete armleocpu_clint; armleocpu_clint = NULL;

    // Fin
    exit(0);
}