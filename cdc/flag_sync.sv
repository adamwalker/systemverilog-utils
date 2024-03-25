/*
 * Synchronize a single bit pulse across clock domains using the toggle method.
 * The input pulse does not need to be stretched, regardless of the relative
 * clock frequencies. 
 * Works well if the clocks are about the same frequency and the 'in' signal
 * is never asserted continuously for more than one cycle.
 */
module flag_sync (
    input  logic clk_in,
    input  logic in,
    
    input  logic clk_out,
    output logic out
);

logic toggle = 0;

always_ff @(posedge clk_in)
    toggle <= toggle ^ in;

(* ASYNC_REG = "true" *) logic toggle_s1 = 0;
(* ASYNC_REG = "true" *) logic toggle_s2 = 0;
                         logic toggle_s3 = 0;

always_ff @(posedge clk_out) begin
    toggle_s1 <= toggle;
    toggle_s2 <= toggle_s1;
    toggle_s3 <= toggle_s2;
end

assign out = toggle_s2 ^ toggle_s3;

endmodule
