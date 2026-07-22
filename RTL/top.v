//==============================================================================
// File   : top.v  |  Module: top  |  Phase 8 - Top Integration
// Wires image_memory, kernel_memory, controller, line_buffer,
// window_generator, mac and output_buffer into the complete NxN convolution
// accelerator. Also performs the small pipeline-alignment shifting (the
// image-memory read register, the window-generator register, and the MAC
// register each add one cycle) needed to keep the "valid window" tag in
// lockstep with the data as it flows through the datapath.
//==============================================================================
module top #(
    parameter PIXEL_W  = 8,
    parameter KERNEL_W = 8,
    parameter ACC_W    = 20,
    parameter IMG_W    = 32,
    parameter IMG_H    = 32,
    parameter K        = 3,
    parameter IMG_ADDRW = 10,        // ceil(log2(IMG_W*IMG_H))
    parameter KIDXW     = 4,         // ceil(log2(K*K))
    parameter OUT_DEPTH  = 1024,
    parameter OUT_AW     = 10
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // control
    input  wire                        start,
    input  wire                        relu_en,
    output wire                        busy,
    output wire                        scan_done,

    // image load interface (host/testbench preloads image_memory)
    input  wire                        img_we,
    input  wire [IMG_ADDRW-1:0]        img_waddr,
    input  wire [PIXEL_W-1:0]          img_wdata,

    // kernel load interface (host/testbench preloads kernel_memory)
    input  wire                        kernel_we,
    input  wire [KIDXW-1:0]            kernel_windex,
    input  wire signed [KERNEL_W-1:0]  kernel_wdata,

    // result stream out
    input  wire                        out_rd_en,
    output wire signed [ACC_W-1:0]     out_data,
    output wire                        out_valid,
    output wire                        out_full
);

    // ---------------- controller ----------------
    wire [IMG_ADDRW-1:0] mem_raddr;
    wire                 streaming;
    wire                 raw_valid;

    controller #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .K(K), .ADDRW(IMG_ADDRW)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start),
        .mem_raddr(mem_raddr), .streaming(streaming), .raw_valid(raw_valid),
        .busy(busy), .scan_done(scan_done)
    );

    // ---------------- image memory ----------------
    wire [PIXEL_W-1:0] pixel_in;
    image_memory #(
        .PIXEL_W(PIXEL_W), .IMG_W(IMG_W), .IMG_H(IMG_H), .ADDRW(IMG_ADDRW)
    ) u_img_mem (
        .clk(clk), .we(img_we), .waddr(img_waddr), .wdata(img_wdata),
        .raddr(mem_raddr), .rdata(pixel_in)
    );

    // ---------------- kernel memory ----------------
    wire signed [K*K*KERNEL_W-1:0] kernel_flat;
    kernel_memory #(
        .K(K), .KERNEL_W(KERNEL_W), .IDXW(KIDXW)
    ) u_kernel_mem (
        .clk(clk), .rst_n(rst_n), .we(kernel_we),
        .windex(kernel_windex), .wdata(kernel_wdata),
        .kernel_flat(kernel_flat)
    );

    // ---------------- pipeline-alignment stage 1: pixel becomes valid ----------------
    reg shift_en_d1;
    reg valid_tag_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_en_d1  <= 1'b0;
            valid_tag_d1 <= 1'b0;
        end else begin
            shift_en_d1  <= streaming;
            valid_tag_d1 <= raw_valid;
        end
    end

    // ---------------- line buffer ----------------
    wire [K*PIXEL_W-1:0] row_taps_flat;
    line_buffer #(
        .PIXEL_W(PIXEL_W), .IMG_W(IMG_W), .K(K)
    ) u_line_buf (
        .clk(clk), .rst_n(rst_n),
        .shift_en(shift_en_d1), .pixel_in(pixel_in),
        .row_taps_flat(row_taps_flat)
    );

    // ---------------- window generator ----------------
    wire [K*K*PIXEL_W-1:0] window_flat;
    window_generator #(
        .PIXEL_W(PIXEL_W), .K(K)
    ) u_win_gen (
        .clk(clk), .rst_n(rst_n),
        .shift_en(shift_en_d1), .row_taps_flat(row_taps_flat),
        .window_flat(window_flat)
    );

    // ---------------- pipeline-alignment stage 2: window becomes valid ----------------
    reg valid_tag_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_tag_d2 <= 1'b0;
        else
            valid_tag_d2 <= valid_tag_d1;
    end

    // ---------------- MAC ----------------
    wire mac_valid_out;
    wire signed [ACC_W-1:0] mac_acc_out;
    mac #(
        .PIXEL_W(PIXEL_W), .KERNEL_W(KERNEL_W), .ACC_W(ACC_W), .K(K)
    ) u_mac (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_tag_d2), .window_flat(window_flat), .kernel_flat(kernel_flat),
        .valid_out(mac_valid_out), .acc_out(mac_acc_out)
    );

    // ---------------- output buffer ----------------
    output_buffer #(
        .ACC_W(ACC_W), .DEPTH(OUT_DEPTH), .AW(OUT_AW)
    ) u_out_buf (
        .clk(clk), .rst_n(rst_n), .relu_en(relu_en),
        .valid_in(mac_valid_out), .data_in(mac_acc_out),
        .rd_en(out_rd_en), .data_out(out_data), .out_valid(out_valid), .full(out_full)
    );

endmodule
