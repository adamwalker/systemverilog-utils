/*
 * Multiplexes multiple input streams onto one output stream. Once a stream is
 * selected, it cannot be interrupted until it ends. This mux is not intended
 * for use on latency sensitive paths as it introduces one cycle of latency
 * from when valid is asserted on an input to when valid is asserted on the
 * output. Also, there will always be one idle cycle on the output after the
 * current stream ends, even if other inputs are currently asserting valid.
 * This is to simplify the design and reduce logic depth.
 *
 * Input streams are assumed to be continuous. Ie, once valid is asserted, the 
 * stream will supply data on every cycle until last is asserted.
 *
 * Timing note: there are no combinational paths between the valid inputs and
 * the ready outputs. There are also no combinational paths between the valid
 * inputs and valid outputs.
 */
module mux #(
    parameter int P_DATA_WIDTH = 32,
    parameter int P_NUM_INPUTS = 3
) (
    input  logic                    clk,
    input  logic                    rst,

    //Inputs:
    input  logic                    valid_in[P_NUM_INPUTS],
    input  logic                    last_in[P_NUM_INPUTS],
    input  logic [P_DATA_WIDTH-1:0] data_in[P_NUM_INPUTS],
    output logic                    ready_in[P_NUM_INPUTS],

    //Output
    output logic                    valid_out,
    output logic                    last_out,
    output logic [P_DATA_WIDTH-1:0] data_out,
    input  logic                    ready_out
);

logic [$clog2(P_NUM_INPUTS)-1:0] sel    = 0;
logic                            active = 0;

//Choose the selector
always_ff @(posedge clk)
    if (rst) begin
        active <= 0;
        sel    <= 0;
    end else if (active) begin
        if (last_out && ready_out) begin
            active <= 0;
        end
    end else begin

        //Set active
        for (int i=0; i<P_NUM_INPUTS; i++)
            if (valid_in[i])
                active <= 1;

        //Priority encode
        //Loop is backwards because Icarus Verilog doesn't support break statements
        for (int i=P_NUM_INPUTS-1; i>=0; i--) 
            if (valid_in[i]) 
                sel <= $clog2(P_NUM_INPUTS)'(i);
    end

//Assign the downstream outputs
always_comb begin
    valid_out = active;
    last_out  = last_in[sel];
    data_out  = data_in[sel];
end

//Assign the upstream outputs
always_comb
    for (int i=0; i<P_NUM_INPUTS; i++)
        //Optimise: one hot encoded sel mask can be precomputed
        ready_in[i] = (sel == $clog2(P_NUM_INPUTS)'(i)) && ready_out && active; 

`ifdef COCOTB_SIM
initial begin
    $dumpfile ("mux.vcd");
    $dumpvars (0, mux);
    #1;
end
`endif

endmodule
