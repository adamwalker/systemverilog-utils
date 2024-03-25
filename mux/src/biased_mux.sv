/*
 * Two input biased stream mux. Multiplexes two input streams onto one output
 * stream. Once a stream is selected, it cannot be interrupted until it ends.
 * Input 0 has no added latency from asserting valid. Input one has one
 * cycle of latency. This is to simplify the logic and reduce logic depth
 * while handling a common case of having only one latency sensitive input. 
 *
 * Input streams are assumed to be continuous. Ie, once valid is asserted, the 
 * stream will supply data on every cycle until last is asserted.
 *
 * Timing note: there are no combinational paths between the valid inputs and
 * the ready outputs.
 */
module biased_mux #(
    parameter int P_DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst,

    //Input 1:
    input  logic                    valid_in_0,
    input  logic                    last_in_0,
    input  logic [P_DATA_WIDTH-1:0] data_in_0,
    output logic                    ready_in_0,

    //Input 2:
    input  logic                    valid_in_1,
    input  logic                    last_in_1,
    input  logic [P_DATA_WIDTH-1:0] data_in_1,
    output logic                    ready_in_1,

    //Output:
    output logic                    valid_out,
    output logic                    last_out,
    output logic [P_DATA_WIDTH-1:0] data_out,
    input  logic                    ready_out,

    //Selector
    output logic                    sel_out
);

logic sel    = 0;
logic active = 0;

assign sel_out = sel;

//Choose the selector
always_ff @(posedge clk)
    if (rst) begin
        active <= 0;
        sel    <= 0;
    end else if (active) begin
        if (last_out && ready_out) begin
            active <= 0;
            sel    <= 0;
        end
    end else begin
        //Set active
        if (valid_in_0 || valid_in_1)
            active <= 1;
        //Choose selector
        if (valid_in_1 && !valid_in_0)
            sel <= 1;
    end

//Assign the downstream outputs
always_comb begin
    valid_out = valid_in_0 || active;
    last_out  = sel ? last_in_1 : last_in_0;
    data_out  = sel ? data_in_1 : data_in_0;
end

//Assign the upstream outputs
always_comb begin
    ready_in_0 = !sel && ready_out;
    ready_in_1 =  sel && ready_out;
end

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("biased_mux.vcd");
  $dumpvars (0, biased_mux);
  #1;
end
`endif

endmodule
