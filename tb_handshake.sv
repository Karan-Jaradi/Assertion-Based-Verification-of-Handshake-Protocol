`timescale 1ns/1ps

module tb_handshake;

    reg clk;
    reg rst;
    reg req;
    wire ack;

    handshake dut (
        .clk(clk),
        .rst(rst),
        .req(req),
        .ack(ack)
    );

    always #5 clk = ~clk;

    // cycle counter
    integer cycle;
    always @(posedge clk) begin
        if (rst)
            cycle <= 0;
        else
            cycle <= cycle + 1;
    end

    // valid req tracking
    reg valid_req;
    always @(posedge clk) begin
        if (rst)
            valid_req <= 1'b0;
        else
            valid_req <= req && (dut.state == 2'b00); // IDLE
    end

    // txn tracking
    integer txn_id;
    integer completed_txn;
    integer req_cycle [0:31];

    always @(posedge clk) begin
        if (rst) begin
            txn_id        <= 0;
            completed_txn <= 0;
        end else begin
            if (valid_req) begin
                req_cycle[txn_id] = cycle;
                txn_id <= txn_id + 1;
                $display("[C=%0d T=%0t] TXN %0d STARTED", cycle, $time, txn_id);
            end

            if (ack) begin
                integer latency;
                latency = cycle - req_cycle[completed_txn];
                $display("[C=%0d T=%0t] TXN %0d COMPLETED | LATENCY = %0d cycles",
                           cycle, $time, completed_txn, latency);
                completed_txn <= completed_txn + 1;
            end
        end
    end

    initial begin
        clk = 0;
        rst = 1;
        req = 0;
        $display("---- Simulation Start ----");

        #20 rst = 0;

        send_req();
        #40 send_req();

        #20;
        $display("[C=%0d T=%0t] Sending INVALID overlapping REQ", cycle, $time);
        req = 1;
        @(posedge clk);
        req = 1;
        @(posedge clk);
        req = 0;

        #100;
        $display("===== SUMMARY =====");
        $display("Total Requests Sent      = %0d", txn_id);
        $display("Total ACKs Received      = %0d", completed_txn);
        $display("Outstanding Transactions = %0d", txn_id - completed_txn);
        $display("---- Simulation End ----");
        $finish;
    end

    task send_req;
        begin
            @(posedge clk);
            $display("[C=%0d T=%0t] REQ asserted", cycle, $time);
            req = 1;
            @(posedge clk);
            req = 0;
        end
    endtask

    always @(posedge clk) begin
        $display("[C=%0d T=%0t] STATE=%s | REQ=%0b | ACK=%0b | COUNT=%0d",
                   cycle, $time,
                   (dut.state==2'b00) ? "IDLE" : "WAIT",
                   req, ack, dut.count);

        if (req && (dut.state != 2'b00)) begin
            $display("[C=%0d T=%0t] PROTOCOL VIOLATION: Overlapping REQ",
                       cycle, $time);
        end
    end

    property ack_wi_5_cycles;
        @(posedge clk)
        disable iff (rst)
        valid_req |-> ##[1:5] ack;
    endproperty
    assert property (ack_wi_5_cycles)
        else $display("[C=%0d T=%0t] ERROR: ACK not within 5 cycles", cycle, $time);

    property ack_one_cycle;
        @(posedge clk)
        disable iff (rst)
        ack |-> ##1 !ack;
    endproperty
    assert property (ack_one_cycle)
        else $display("[C=%0d T=%0t] ERROR: ACK not single-cycle", cycle, $time);

    property no_spurious_ack;
        @(posedge clk)
        disable iff (rst)
        ack |-> (
            $past(valid_req,1) ||
            $past(valid_req,2) ||
            $past(valid_req,3) ||
            $past(valid_req,4) ||
            $past(valid_req,5)
        );
    endproperty
    assert property (no_spurious_ack)
        else $display("[C=%0d T=%0t] ERROR: Spurious ACK detected", cycle, $time);

endmodule
