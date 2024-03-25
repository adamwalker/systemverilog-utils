/*
 * Low capacity CDC FIFO with Gray coded pointers.
 * Not intended to provide significant buffering.
 * Identical to the async_fifo module, except that it doesn't check if the
 * FIFO is full, and is slightly more efficient as a result. 
 * Useful if you do not need backpressure (i.e no full signal), because you know that
 * you will always be reading the data as fast as it is written.
 */
module cdc_fifo # (
    parameter P_DATA_WIDTH = 32
) (
    //Write clock domain
    input  logic                    clk_in,
    input  logic                    write,
    input  logic [P_DATA_WIDTH-1:0] data_in,

    //Read clock domain
    input  logic                    clk_out,
    input  logic                    read,
    output logic [P_DATA_WIDTH-1:0] data_out,
    output logic                    empty
);

//The data ram. Read combinationally, so should be implemented using
//distributed ram on Xilinx FPGAs
logic [P_DATA_WIDTH-1:0] ram [16] = '{default: 0};

//Pointers are synced across clock domains using gray code. 
//Pointers are also always stored in gray code, so a small lookup table is
//used to implement the increment operation.
localparam [3:0] gray_inc[16] = '{
    4'b0001, //0000
    4'b0011, //0001
    4'b0110, //0010
    4'b0010, //0011
    4'b1100, //0100
    4'b0100, //0101
    4'b0111, //0110
    4'b0101, //0111
    4'b0000, //1000
    4'b1000, //1001
    4'b1011, //1010
    4'b1001, //1011
    4'b1101, //1100
    4'b1111, //1101
    4'b1010, //1110
    4'b1110  //1111
};

//The pointers
logic [3:0] wptr = 0;
(* ASYNC_REG = "true" *) logic [3:0] wptr_rd0 = 0;
(* ASYNC_REG = "true" *) logic [3:0] wptr_rd1 = 0;

logic [3:0] rptr = 0;

//Update the write pointer and memory
always_ff @(posedge clk_in)
    if (write) begin
        wptr <= gray_inc[wptr];
        ram[wptr] <= data_in;
    end

//Update the read pointer and read from the memory
always_ff @(posedge clk_out)
    if (read && !empty)
        rptr <= gray_inc[rptr];

assign data_out = ram[rptr];

//Sync the write pointer to the read domain
always_ff @(posedge clk_out) begin
    wptr_rd0 <= wptr;
    wptr_rd1 <= wptr_rd0;
end

//Calculate the full/empty flags
assign empty = rptr == wptr_rd1;

endmodule

