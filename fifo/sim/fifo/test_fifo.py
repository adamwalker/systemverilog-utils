import itertools
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_bus.monitors import Monitor
from cocotb_bus.scoreboard import Scoreboard

class NonEmptyMonitor(Monitor):
    """Valid monitor"""

    def __init__(self, clk, valid, ready, data):
        self.name = "Non empty monitor"

        self.clk   = clk
        self.valid = valid
        self.ready = ready
        self.data  = data

        Monitor.__init__(self, None, None)

    async def _monitor_recv(self):
        while True:
            await RisingEdge(self.clk)
            if (not self.valid.value and self.ready.value):
                val = self.data.value
                self._recv(val)

async def set_bit_sequence(clk, sig, bit_generator):
    for val in bit_generator:
        await RisingEdge(clk)
        sig.value = val

def random_gen():
    while True:
        yield random.choice([0, 1])

NUM_ITEMS = 10000

@cocotb.test()
async def test_fifo(dut):
    """ FIFO test """

    ADDR_WIDTH = 4 #int(dut.P_ADDR_WIDTH.value)
    DATA_WIDTH = 32 #int(dut.P_DATA_WIDTH.value)

    dut.rst.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.data_in.value = 0
    dut.rst.value = 0

    #Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    #Valid
    vld_gen = cocotb.start_soon(set_bit_sequence(dut.clk, dut.wr_en, random_gen()))

    #Ready
    cocotb.start_soon(set_bit_sequence(dut.clk, dut.rd_en, random_gen()))

    #Monitor output
    output_mon = NonEmptyMonitor(clk=dut.clk, valid=dut.empty, ready=dut.rd_en, data=dut.data_out)
    scoreboard = Scoreboard(dut)
    exp_out = []
    scoreboard.add_interface(output_mon, exp_out)

    cnt = 0
    while (cnt < NUM_ITEMS):
        await RisingEdge(dut.clk)
        if(dut.wr_en.value and not dut.full.value):
            exp_out.append(dut.data_in.value)
            x = random.randint(0, 2**DATA_WIDTH - 1)
            dut.data_in.value = x
            cnt = cnt + 1

    vld_gen.kill()
    dut.wr_en.value = False

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while (not dut.empty.value):
        await RisingEdge(dut.clk)

    raise scoreboard.result

