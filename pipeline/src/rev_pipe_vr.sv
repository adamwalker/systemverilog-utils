/*
 * Reverse pipeline module for data exchanged using valid and ready handshaking.
 * Breaks combinational logic paths in the reverse direction. Specifically,
 * just the 'ready' signal. Does not break the 'valid' and 'data' paths.
 * To break the 'valid' and 'data' paths, use the fwd_pipe_vr module.
 */
module rev_pipe_vr #(
    parameter int P_DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst,

    //Input data stream:
    input  logic                    valid_in,
    input  logic [P_DATA_WIDTH-1:0] data_in,
    output logic                    ready_in,

    //Output data steam:
    output logic                    valid_out,
    output logic [P_DATA_WIDTH-1:0] data_out,
    input  logic                    ready_out
);

logic [P_DATA_WIDTH-1:0] data_saved;
logic                    ready_in_p = 1;
assign ready_in = ready_in_p;

always_ff @(posedge clk) begin
    
    if (rst)
        ready_in_p <= 1;
    else
        ready_in_p <= ready_out || !valid_out;

    if (ready_in_p)
        data_saved <= data_in;
end

assign valid_out = valid_in || !ready_in_p;

assign data_out = ready_in_p ? data_in : data_saved;

endmodule
