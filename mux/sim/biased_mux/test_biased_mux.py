import itertools
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb_bus.monitors import Monitor
from cocotb_bus.scoreboard import Scoreboard

class ValidMonitor(Monitor):
    """Valid monitor"""

    def __init__(self, clk, valid, last, ready, data):
        self.name = "Valid monitor"

        self.clk   = clk
        self.valid = valid
        self.ready = ready
        self.data  = data
        self.last  = last

        self.buf = []

        Monitor.__init__(self, None, None)

    async def _monitor_recv(self):
        while True:
            await RisingEdge(self.clk)
            if (self.valid.value and self.ready.value):
                val = self.data.value
                self.buf.append(val)
                if (self.last.value):
                    self._recv(self.buf)
                    self.buf = []

async def set_bit_sequence(clk, sig, bit_generator):
    for val in bit_generator:
        await RisingEdge(clk)
        sig.value = val

def random_gen():
    while True:
        yield random.choice([0, 1])

async def stim(exp_out, clk, valid, data, last, ready):
    DATA_WIDTH = 32 #int(dut.P_DATA_WIDTH.value)
    pkt_buf = []

    for i in range(1000):
        cnt = 0
        size = random.randint(2, 32)
        gap  = random.randint(0, 32)

        #Random nonvalid period
        valid.value = 0;

        for _ in range(gap):
            await RisingEdge(clk)

        valid.value = 1;

        #Send the packet
        while (cnt < size):

            #Set the inputs
            x = random.randint(0, 2**DATA_WIDTH - 1)
            data.value = x
            pkt_buf.append(x)

            if (cnt == size - 1):
                last.value = 1
                exp_out.append(pkt_buf)
                pkt_buf = [];
            else:
                last.value = 0

            cnt = cnt + 1

            while True:
                await RisingEdge(clk)
                if ready.value:
                    break

    valid.value = 0;

@cocotb.test()
async def test_biased_mux(dut):
    """ Biased mux test """

    dut.rst.value = 0

    #Port 1
    dut.valid_in_0.value = 0
    dut.last_in_0.value = 0
    dut.data_in_0.value = 0

    #Port 2
    dut.valid_in_1.value = 0
    dut.last_in_1.value = 0
    dut.data_in_1.value = 0

    #Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    #Ready
    cocotb.start_soon(set_bit_sequence(dut.clk, dut.ready_out, random_gen()))

    #Monitor output
    output_mon = ValidMonitor(clk=dut.clk, valid=dut.valid_out, last=dut.last_out, ready=dut.ready_out, data=dut.data_out)
    scoreboard = Scoreboard(dut)
    exp_out = []
    scoreboard.add_interface(output_mon, exp_out)

    s0 = cocotb.start_soon(stim(exp_out, dut.clk, dut.valid_in_0, dut.data_in_0, dut.last_in_0, dut.ready_in_0))
    s1 = cocotb.start_soon(stim(exp_out, dut.clk, dut.valid_in_1, dut.data_in_1, dut.last_in_1, dut.ready_in_1))

    await s0
    await s1

    await RisingEdge(dut.clk)

    raise scoreboard.result

