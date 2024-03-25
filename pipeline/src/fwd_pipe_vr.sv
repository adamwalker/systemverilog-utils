/*
 * Forward pipeline module for data exchanged using valid and ready handshaking.
 * Breaks combinational logic paths in the forward direction. Specifically,
 * the 'valid' and 'data' signals. Does not break the 'ready' path.
 * To break the 'ready' path, use the rev_pipe_vr module.
 */
module fwd_pipe_vr #(
    parameter int P_DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst,

    //Input data stream:
    input  logic                    valid_in,
    input  logic [P_DATA_WIDTH-1:0] data_in,
    output logic                    ready_in,

    //Output data stream:
    output logic                    valid_out,
    output logic [P_DATA_WIDTH-1:0] data_out,
    input  logic                    ready_out
);

logic  valid_out_p = 0;
assign valid_out = valid_out_p;

always_ff @(posedge clk) begin
    
    if (rst)
        valid_out_p <= 0;
    else
        valid_out_p <= valid_in || !ready_in;

    if (ready_in)
        data_out <= data_in;
end

assign ready_in = ready_out || !valid_out_p;

endmodule
