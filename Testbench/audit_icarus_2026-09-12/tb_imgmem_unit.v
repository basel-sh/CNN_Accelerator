//==============================================================================
// tb_imgmem_unit.v — direct unit-level testbench for image_memory_2px.v
// Covers: ERR-01 (write-address wraparound beyond the declared width)
//==============================================================================
`timescale 1ns/1ps
module tb_imgmem_unit;
    localparam Pixel_W=8, Img_W=6, Img_H=6, Addrw=6; // Total_Pix=36, Addrw=6 -> addr space 0..63
    reg Clk=0, We=0;
    reg [Addrw-1:0] Waddr=0;
    reg [Pixel_W-1:0] Wdata=0;
    reg [Addrw-1:0] Raddr0=0, Raddr1=0;
    wire [Pixel_W-1:0] Rdata0, Rdata1;

    image_memory_2px #(.Pixel_W(Pixel_W), .Img_W(Img_W), .Img_H(Img_H), .Addrw(Addrw)) Dut (
        .Clk(Clk), .We(We), .Waddr(Waddr), .Wdata(Wdata),
        .Raddr0(Raddr0), .Raddr1(Raddr1), .Rdata0(Rdata0), .Rdata1(Rdata1)
    );
    always #5 Clk = ~Clk;

    integer pass_count=0, fail_count=0;
    task automatic check(input cond, input [8*160-1:0] name);
        begin
            if (cond) begin pass_count=pass_count+1; $display("CHECK PASS: %0s", name); end
            else begin fail_count=fail_count+1; $display("CHECK FAIL: %0s", name); end
        end
    endtask

    integer i;
    reg [7:0] wide_addr; // wider than Addrw, to model an address that "goes past" Total_Pix

    initial begin
        // Preload a distinguishing value at address 5 (within range, untouched later) and clear address 0.
        for (i=0;i<Img_W*Img_H;i=i+1) begin
            @(negedge Clk); We=1; Waddr=i[Addrw-1:0]; Wdata=8'h00;
        end
        @(negedge Clk); We=1; Waddr=5; Wdata=8'hAA; // marker at addr 5, should survive
        @(negedge Clk); We=0;

        // Write to address 64 (= 2^Addrw), which truncates/wraps to address 0 in a 6-bit port.
        wide_addr = 8'd64;
        @(negedge Clk);
        We = 1; Waddr = wide_addr[Addrw-1:0]; Wdata = 8'h5A; // wraps to addr 0
        @(negedge Clk);
        We = 0;

        // Read back address 0 (should now hold the wrapped write's value)
        @(negedge Clk); Raddr0 = 0; Raddr1 = 5;
        @(posedge Clk); #1;
        @(posedge Clk); #1; // Rdata is a registered read, needs one extra edge to settle
        check(Rdata0 == 8'h5A, "ERR-01: write to address 2^Addrw wraps cleanly to address 0, no X/corruption");
        check(Rdata1 == 8'hAA, "ERR-01: the wrapped write does not disturb an unrelated address (addr 5 unaffected)");

        $display("TB_IMGMEM_UNIT: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule
