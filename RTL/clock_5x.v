//==============================================================================
// clock_5x.v | 6x internal clock for DSP time-multiplexing
//
// Reference clock: 20 MHz (50 ns)
// Fast clock:      120 MHz (8.333 ns)
// VCO:             960 MHz
//
// Five fast cycles are sufficient for all 18 products, leaving timing margin
// inside each 50 ns system transaction while still using only four DSPs.
//==============================================================================
module clock_5x (
    input  wire Clk_In,
    input  wire Rst_N,
    output wire Clk_Fast,
    output wire Locked
);
    wire Clk_Fast_Raw;
    wire Clk_Fb;
    wire Clk_Fb_Buf;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(48.0),
        .CLKFBOUT_PHASE(0.0),
        .CLKIN1_PERIOD(50.000),
        .CLKOUT0_DIVIDE_F(8.0),
        .CLKOUT0_PHASE(0.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .DIVCLK_DIVIDE(1),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) U_MMCM (
        .CLKIN1(Clk_In),
        .CLKFBIN(Clk_Fb_Buf),
        .RST(~Rst_N),
        .PWRDWN(1'b0),
        .CLKFBOUT(Clk_Fb),
        .CLKOUT0(Clk_Fast_Raw),
        .LOCKED(Locked)
    );

    BUFG U_BUFG_FB (
        .I(Clk_Fb),
        .O(Clk_Fb_Buf)
    );

    BUFG U_BUFG_FAST (
        .I(Clk_Fast_Raw),
        .O(Clk_Fast)
    );
endmodule
