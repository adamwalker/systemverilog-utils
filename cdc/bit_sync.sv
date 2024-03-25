/*
 * Minimal two stage flop synchronizer
 */
module bit_sync (
    input  logic in,
    
    input  logic clk_out,
    output logic out
);

(* ASYNC_REG = "true" *) logic bit_s1 = 0;
(* ASYNC_REG = "true" *) logic bit_s2 = 0;

always_ff @(posedge clk_out) begin
    bit_s1 <= in;
    bit_s2 <= bit_s1;
end

assign out = bit_s2;

endmodule
