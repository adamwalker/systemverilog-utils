/*
 * A reset synchronizer. Allows a reset signal to be asynchronously asserted,
 * and synchronously deasserted.
 * When 'rst_in' is asserted, 'rst_out' is immediately asserted, whether the
 * clock is running or not.
 * 'rst_out' will be deasserted a few cycles later *synchronous* to the clock.
 */
module reset_sync (
    input  logic clk,
    input  logic rst_in,
    output logic rst_out
);

(* ASYNC_REG = "true" *) logic rst_0 = 1'b0;
(* ASYNC_REG = "true" *) logic rst_1 = 1'b0;
(* ASYNC_REG = "true" *) logic rst_2 = 1'b0;
(* ASYNC_REG = "true" *) logic rst_3 = 1'b0;

always_ff @(posedge clk, posedge rst_in)
    if (rst_in) begin
        rst_0 <= 1'b1;
        rst_1 <= 1'b1;
        rst_2 <= 1'b1;
        rst_3 <= 1'b1;
    end else begin
        rst_0 <= 1'b0;
        rst_1 <= rst_0;
        rst_2 <= rst_1;
        rst_3 <= rst_2;
    end

assign rst_out = rst_3;

endmodule
