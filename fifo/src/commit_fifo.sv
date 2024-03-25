/*
 * Synchronous FIFO with the ability to roll back transactions if the FIFO
 * overflows. 
 *
 * In addition to a write pointer, it keeps a committed pointer. The write
 * pointer is advanced as data is written. The committed pointer is only
 * updated if the stream ends without an overflow. Data is only available on
 * the output once the committed pointer has been advanced. 
 *
 * Uses the trick where the pointers are extended by a single bit to
 * distinguish the full and empty cases. See page 3 of "Simulation and 
 * Synthesis Techniques for Asynchronous FIFO Design" by Clifford Cummings.
 *
 * TODO: allow for rollbacks other than running out of space, and for commits
 * and rollbacks to happen when 'wr_en' is not asserted.
 */
module commit_fifo #(
    parameter int P_ADDR_WIDTH = 5,
    parameter int P_DATA_WIDTH = 32

) (
    input  logic                    clk,
    input  logic                    rst,

    //Input:
    input  logic                    wr_en,
    input  logic                    commit,
    input  logic [P_DATA_WIDTH-1:0] data_in,
    output logic                    full,

    //Output
    input  logic                    rd_en,
    output logic [P_DATA_WIDTH-1:0] data_out,
    output logic                    empty
);

//The RAM and pointers
logic [P_DATA_WIDTH-1:0] ram [2**P_ADDR_WIDTH];

logic [P_ADDR_WIDTH:0] waddr_q = 0;
logic [P_ADDR_WIDTH:0] waddr_commit = 0;
logic [P_ADDR_WIDTH:0] raddr_q = 0;

logic  addr_eq;
logic  addr_wrap;
assign addr_eq   = raddr_q[P_ADDR_WIDTH-1:0] == waddr_q[P_ADDR_WIDTH-1:0];
assign addr_wrap = raddr_q[P_ADDR_WIDTH]     != waddr_q[P_ADDR_WIDTH]; //To distinguish full and empty

//Write logic
logic [P_ADDR_WIDTH:0] waddr_inc;
assign waddr_inc = waddr_q + 'd1;
assign full = addr_eq && addr_wrap;

always_ff @(posedge clk)
    if (wr_en && !full)
        ram[waddr_q[P_ADDR_WIDTH-1:0]] <= data_in;

//'1' if there has been an error and we will not commit when the stream ends
logic discarding = 0;

always_ff @(posedge clk)
    if (rst)
        discarding <= 0;
    else if (wr_en)
        if (commit)
            discarding <= 0;
        else if (full)
            discarding <= 1;

always_ff @(posedge clk)
    if (rst) begin
        waddr_q      <= 0;
        waddr_commit <= 0;
    end else if (wr_en)

        if (full || discarding) begin
            waddr_q <= waddr_commit;
        end else begin
            waddr_q <= waddr_inc;
            if (commit)
                waddr_commit <= waddr_inc;
        end

        //Alternative implementation
        //if (commit)
        //    if (full || discarding)
        //        waddr_q <= waddr_commit;
        //    else begin
        //        waddr_q      <= waddr_inc;
        //        waddr_commit <= waddr_inc;
        //    end
        //else if (!full)
        //    waddr_q <= waddr_inc;

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
assign empty_p = waddr_commit == raddr_q;

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
        raddr_q <= raddr_q + 1;

always_ff @(posedge clk)
    if (ready)
        data_out <= ram[raddr_q[P_ADDR_WIDTH-1:0]];

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("commit_fifo.vcd");
  $dumpvars (0, commit_fifo);
  #1;
end
`endif

endmodule
