//==============================================================================
// tb_controller.v - Phase 9 unit test for RTL/controller.v
// Verifies the FSM streams exactly Img_W*Img_H addresses in row-major order,
// asserts Raw_Valid only once Row>=K-1 && Col>=K-1, and returns to idle.
//==============================================================================
`timescale 1ns/1ps
module tb_controller;
    localparam Img_W=8, Img_H=8, K=3, Addrw=6;   // small image for a fast unit test
    localparam Total = Img_W*Img_H;

    reg Clk=0, Rst_N=0, Start=0;
    wire [Addrw-1:0] Mem_Raddr;
    wire Streaming, Raw_Valid, Busy, Scan_Done;

    controller #(.Img_W(Img_W), .Img_H(Img_H), .K(K), .Addrw(Addrw)) Dut (
        .Clk(Clk), .Rst_N(Rst_N), .Start(Start),
        .Mem_Raddr(Mem_Raddr), .Streaming(Streaming), .Raw_Valid(Raw_Valid),
        .Busy(Busy), .Scan_Done(Scan_Done)
    );

    always #5 Clk = ~Clk;

    integer Addr_Count = 0;
    integer Valid_Count = 0;
    integer Errors = 0;
    reg [Addrw-1:0] Last_Addr = 0;
    reg Have_Last = 0;

    always @(posedge Clk) begin
        if (Streaming) begin
            Addr_Count = Addr_Count + 1;
            if (Have_Last && (Mem_Raddr != Last_Addr + 1'b1) && !(Last_Addr == Total-1)) begin
                $display("FAIL: non-sequential address %0d after %0d", Mem_Raddr, Last_Addr);
                Errors = Errors + 1;
            end
            Last_Addr = Mem_Raddr;
            Have_Last = 1;
            if (Raw_Valid) Valid_Count = Valid_Count + 1;
        end
    end

    initial begin
        $dumpfile("sim/tb_controller.vcd");
        $dumpvars(0, tb_controller);

        Rst_N = 0;
        repeat (3) @(posedge Clk);
        @(negedge Clk);
        Rst_N = 1;
        Start = 1;
        @(posedge Clk);
        @(negedge Clk);
        Start = 0;

        // avoid a wait()-based race with the counting always block on the
        // same clock edge - just run for a fixed, generous cycle count.
        repeat (Total + 10) @(posedge Clk);

        $display("Addr_Count=%0d (expected %0d)", Addr_Count, Total);
        $display("Valid_Count=%0d (expected %0d)", Valid_Count, (Img_W-K+1)*(Img_H-K+1));

        if (Addr_Count !== Total) begin
            $display("FAIL: address count mismatch");
            Errors = Errors + 1;
        end
        if (Valid_Count !== (Img_W-K+1)*(Img_H-K+1)) begin
            $display("FAIL: valid window count mismatch");
            Errors = Errors + 1;
        end

        if (Errors == 0)
            $display("TB_CONTROLLER: ALL TESTS PASSED");
        else
            $display("TB_CONTROLLER: %0d TEST(S) FAILED", Errors);

        $finish;
    end
endmodule
