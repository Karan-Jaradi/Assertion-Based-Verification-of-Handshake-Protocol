module handshake (
    input clk,
    input rst,
    input req,
    output reg ack
);

    // state encoding
    parameter IDLE = 2'b00,
              WAIT = 2'b01;

    reg [1:0] state;
    reg [2:0] count;

    // main
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            count <= 3'd0;
            ack   <= 1'b0;
        end else begin
            // default outputs
            ack <= 1'b0;

            case (state)
                // idle
                IDLE: begin
                    count <= 3'd0;
                    if (req) begin
                        state <= WAIT;
                    end
                end

                // wait
                WAIT: begin
                    count <= count + 1;
                    // generate ack exactly at 5th cycle
                    if (count == 3'd3) begin
                        ack   <= 1'b1;  // single-cycle pulse
                        state <= IDLE;  // immediately return
                        count <= 3'd0;
                    end
                end
            endcase
        end
    end

endmodule
