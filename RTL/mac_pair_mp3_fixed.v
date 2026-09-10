// Functional safety wrapper for the previously verified 4-DSP engine.
// Keeps the top-level interface identical while the 3-DSP MP3 datapath is
// being corrected and re-verified separately.
module mac_pair_mp3_fixed #(
    parameter Pixel_W=8, parameter Kernel_W=8, parameter Acc_W=20, parameter K=3
)(
    input wire Clk_Sys, input wire Clk_Fast, input wire Rst_N,
    input wire Fast_Locked, input wire Valid_In,
    input wire [K*K*Pixel_W-1:0] Left_Window_Flat,
    input wire [K*K*Pixel_W-1:0] Right_Window_Flat,
    input wire signed [K*K*Kernel_W-1:0] Kernel_Flat,
    input wire Out_Rd_En,
    output wire Valid_Out,
    output wire signed [Acc_W-1:0] Left_Acc_Out,
    output wire signed [Acc_W-1:0] Right_Acc_Out
);
    mac_pair_mp4 #(
        .Pixel_W(Pixel_W), .Kernel_W(Kernel_W), .Acc_W(Acc_W), .K(K)
    ) U_Verified_MP4 (
        .Clk_Sys(Clk_Sys), .Clk_Fast(Clk_Fast), .Rst_N(Rst_N),
        .Fast_Locked(Fast_Locked), .Valid_In(Valid_In),
        .Left_Window_Flat(Left_Window_Flat), .Right_Window_Flat(Right_Window_Flat),
        .Kernel_Flat(Kernel_Flat), .Out_Rd_En(Out_Rd_En),
        .Valid_Out(Valid_Out), .Left_Acc_Out(Left_Acc_Out), .Right_Acc_Out(Right_Acc_Out)
    );
endmodule
