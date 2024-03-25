import itertools
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_bus.monitors import Monitor
from cocotb_bus.scoreboard import Scoreboard

class ValidMonitor(Monitor):
    """Valid monitor"""

    def __init__(self, clk, valid, ready, data):
        self.name = "Valid monitor"

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

@cocotb.test()
async def test_commit_fifo(dut):
    """ FIFO test """

    ADDR_WIDTH = 4 #int(dut.P_ADDR_WIDTH.value)
    DATA_WIDTH = 32 #int(dut.P_DATA_WIDTH.value)

    dut.rst.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.data_in.value = 0
    dut.commit.value = 0

    #Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    #Valid
    cocotb.start_soon(set_bit_sequence(dut.clk, dut.wr_en, random_gen()))

    #Ready
    cocotb.start_soon(set_bit_sequence(dut.clk, dut.rd_en, random_gen()))

    #Monitor output
    output_mon = ValidMonitor(clk=dut.clk, valid=dut.empty, ready=dut.rd_en, data=dut.data_out)
    scoreboard = Scoreboard(dut)
    exp_out = []
    scoreboard.add_interface(output_mon, exp_out)

    pkt_accum = []
    aborted = False
    committed = 0

    for i in range(1000):
        pkt_cnt = 0
        pkt_size = random.randint(1, 32)
        while (pkt_cnt < pkt_size):
            await RisingEdge(dut.clk)
            if (dut.wr_en.value):
                #Count words in the packet
                pkt_cnt = pkt_cnt + 1
                #Check for abort
                if (dut.full.value):
                    aborted = True
                #Append to the packet expect queue
                pkt_accum.append(dut.data_in.value)
                if (dut.commit.value):
                    if (not aborted):
                        exp_out.extend(pkt_accum)
                        committed = committed + 1
                    aborted = False
                    pkt_accum = []
                #Assign the next data
                x = random.randint(0, 2**DATA_WIDTH - 1)
                dut.data_in.value = x
                #Assign the next commit
                if (pkt_cnt == pkt_size - 1):
                    dut.commit.value = 1
                else:
                    dut.commit.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while (not dut.empty.value):
        await RisingEdge(dut.clk)

    print("commited: ")
    print(committed)

    raise scoreboard.result

