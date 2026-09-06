//==============================================================================
// cnn_if.sv | Interface: cnn_if
// Bundles every RTL/top.v port plus a handful of whitebox probes (driven by
// tb_top_sv.sv via hierarchical reference into RTL/controller.v) needed for
// FSM/timing coverage that isn't observable at the black-box boundary.
//==============================================================================
interface cnn_if #(
    parameter int PIXEL_W   = 8,
    parameter int KERNEL_W  = 8,
    parameter int ACC_W     = 20,
    parameter int IMG_ADDRW = 10,
    parameter int KIDXW     = 4
) (input logic Clk);

  // Rst_N is driven directly by the driver (asynchronous, not through a
  // clocking block) and fanned out to the DUT and every passive observer.
  logic                        Rst_N;
  logic                        Start, Relu_En;
  logic                        Busy, Scan_Done;
  logic                        Img_We;
  logic [IMG_ADDRW-1:0]        Img_Waddr;
  logic [PIXEL_W-1:0]          Img_Wdata;
  logic                        Kernel_We;
  logic [KIDXW-1:0]            Kernel_Windex;
  logic signed [KERNEL_W-1:0]  Kernel_Wdata;
  logic                        Out_Rd_En;
  logic signed [ACC_W-1:0]     Out_Data;
  logic                        Out_Valid, Out_Full;

  // ---- whitebox probes (assigned from tb_top_sv.sv) ----
  logic [1:0]            wb_state;        // controller.v State (S_Idle/S_Run/S_Done)
  logic                  wb_raw_valid;    // controller.v Raw_Valid
  logic                  wb_streaming;    // controller.v Streaming
  logic [IMG_ADDRW-1:0]  wb_mem_raddr;    // controller.v Mem_Raddr

  clocking drv_cb @(posedge Clk);
    output Start, Relu_En, Img_We, Img_Waddr, Img_Wdata,
           Kernel_We, Kernel_Windex, Kernel_Wdata, Out_Rd_En;
    input  Busy, Scan_Done, Out_Data, Out_Valid, Out_Full;
  endclocking

  clocking mon_cb @(posedge Clk);
    input Start, Relu_En, Img_We, Img_Waddr, Img_Wdata,
          Kernel_We, Kernel_Windex, Kernel_Wdata, Out_Rd_En,
          Busy, Scan_Done, Out_Data, Out_Valid, Out_Full,
          wb_state, wb_raw_valid, wb_streaming, wb_mem_raddr;
  endclocking

  modport DRV (clocking drv_cb, output Rst_N);
  modport MON (clocking mon_cb, input Rst_N);

endinterface
