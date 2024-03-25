/*
 * Synchronous FIFO. 
 *
 * Uses the trick where the pointers are extended by a single bit to
 * distinguish the full and empty cases. See page 3 of "Simulation and 
 * Synthesis Techniques for Asynchronous FIFO Design" by Clifford Cummings.
 */
module fifo #(
    parameter int P_ADDR_WIDTH = 4,
    parameter int P_DATA_WIDTH = 32

) (
    input  logic                    clk,
    input  logic                    rst,

    //Input:
    input  logic                    wr_en,
    input  logic [P_DATA_WIDTH-1:0] data_in,
    output logic                    full,

    //Output
    input  logic                    rd_en,
    output logic [P_DATA_WIDTH-1:0] data_out,
    output logic                    empty
);

//Storage memory
logic [P_DATA_WIDTH-1:0] ram [2**P_ADDR_WIDTH];

//Read/write addresses
logic [P_ADDR_WIDTH:0] waddr_q = 'h0;
logic [P_ADDR_WIDTH:0] raddr_q = 'h0;

logic  addr_eq;
logic  addr_wrap;
assign addr_eq   = raddr_q[P_ADDR_WIDTH-1:0] == waddr_q[P_ADDR_WIDTH-1:0];
assign addr_wrap = raddr_q[P_ADDR_WIDTH]     != waddr_q[P_ADDR_WIDTH]; //To distinguish full and empty

//Write logic
assign full = addr_eq && addr_wrap;

always_ff @(posedge clk) begin
    if (wr_en && !full) begin
        ram[waddr_q[P_ADDR_WIDTH-1:0]] <= data_in;
        waddr_q                        <= waddr_q + 1'd1;
    end
    if (rst)
        waddr_q <= 'h0;
end

//Read logic

/*
 * When building FIFOs out of block RAMs on Xilinx FPGAs, it is a good idea to
 * make use of the RAM's output register, since without it, the combinational
 * delay for data being read from the RAM is high. A lot of the logic below is
 * for doing that while maintaining FWFT operation.
 */

//Asserted if the RAM part of the FIFO is empty. There may be valid data in
//the RAM output register when this signal is asserted. 
logic  empty_p;
assign empty_p = addr_eq && !addr_wrap;

//'1' if the block RAM's output register is not holding valid FIFO data, ie.
//is available.
logic output_slot_avail = 1'b1;
logic ready;

always_ff @(posedge clk)
    if (rst)
        output_slot_avail <= 1'b1;
    else 
        output_slot_avail <= empty_p && ready; 

//We're ready to read from the RAM and into the RAM's output register
assign ready = rd_en || output_slot_avail;
//We're empty if the output register isn't occupied
assign empty = output_slot_avail;

//The actual read address updates and ram reads
always_ff @(posedge clk) 
    if (rst)
        raddr_q <= 'h0;
    else if (ready && !empty_p)
        raddr_q <= raddr_q + 'd1;

always_ff @(posedge clk)
    if (ready)
        data_out <= ram[raddr_q[P_ADDR_WIDTH-1:0]];

endmodule
