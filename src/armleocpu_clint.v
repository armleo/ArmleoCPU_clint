module armleocpu_clint(
    clk, rst_n,
    AXI_AWADDR, AXI_AWVALID, AXI_AWREADY,
    AXI_WDATA, AXI_WSTRB, AXI_WVALID, AXI_WREADY,
    AXI_BRESP, AXI_BVALID, AXI_BREADY,
    AXI_ARADDR, AXI_ARVALID, AXI_ARREADY,
    AXI_RDATA, AXI_RRESP, AXI_RVALID, AXI_RREADY,
    hart_swi, hart_timeri
);

    parameter HART_COUNT = 8; // Valid range: 1 .. 16
    parameter HART_COUNT_WIDTH = 3;

    input clk;
    input rst_n;


    // address write bus
    input [15:0]                AXI_AWADDR;
    input                       AXI_AWVALID;
    output reg                  AXI_AWREADY;
    


    // Write bus
    input  [31:0]               AXI_WDATA;
    input   [3:0]               AXI_WSTRB;
    input                       AXI_WVALID;
    output reg                  AXI_WREADY;

    // Burst response bus
    output reg [1:0]            AXI_BRESP;
    reg [1:0]                   AXI_BRESP_nxt;
    output reg                  AXI_BVALID;
    input                       AXI_BREADY;


    // Address read bus
    input  [15:0]               AXI_ARADDR;
    input                       AXI_ARVALID;
    output reg                  AXI_ARREADY;

    // Read data bus
    output reg [31:0]           AXI_RDATA;
    output reg [1:0]            AXI_RRESP;
    reg [1:0]                   AXI_RRESP_nxt;
    output reg                  AXI_RVALID;
    input                       AXI_RREADY;


    output reg [HART_COUNT-1:0] hart_swi;

    output reg [HART_COUNT-1:0] hart_timeri;



reg [63:0] mtime;

reg [2:0] state;
reg [2:0] state_nxt;  // COMB
localparam STATE_WAIT_ADDRESS = 3'd0,
    STATE_WRITE_DATA = 3'd1,
    STATE_OUTPUT_READDATA = 3'd2,
    STATE_SKIP_WRITE_DATA = 3'd3,
    STATE_WRITE_RESPOND = 3'd4;

reg [63:0] mtimecmp [HART_COUNT-1:0];

reg [15:0] address;
reg [15:0] address_nxt; // COMB

 // COMB ->
reg msip_sel, mtimecmp_high_sel, mtimecmp_low_sel, mtime_low_sel, mtime_high_sel;
reg [3:0] address_hart_id;
reg address_nxt_match_any;


always @* begin : address_nxt_match_logic_always_comb
    address_nxt_match_any = 0;
    address_hart_id = address_nxt[5:2];
    msip_sel = 0;
    mtimecmp_high_sel = 0;
    mtimecmp_low_sel = 0;
    mtime_high_sel = 0;
    mtime_low_sel = 0;
    if(address_nxt[15:6] == 0) begin
        msip_sel = 1;
        address_hart_id = address_nxt[5:2];
        address_nxt_match_any = address_hart_id < HART_COUNT;
    end else if(address_nxt[15:12] == 4'h4 && address_nxt[11:7] == 5'b0) begin
        if(address_nxt[2])
            mtimecmp_high_sel = 1;
        else
            mtimecmp_low_sel = 1;
        address_hart_id = address_nxt[6:3];
        address_nxt_match_any = address_hart_id < HART_COUNT;
    end else if(address_nxt == 16'hBFF8) begin
        mtime_low_sel = 1;
        address_nxt_match_any = 1;
    end else if(address_nxt == 16'hBFF8 + 4) begin
        mtime_high_sel = 1;
        address_nxt_match_any = 1;
    end
end


always @(posedge clk) begin : main_always_ff
    reg [HART_COUNT_WIDTH:0] i;
    if(!rst_n) begin
        mtime <= 0;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            /* verilator lint_off WIDTH */
            hart_timeri[i] <= 1'b0;
            mtimecmp[i]  <= -64'd1;
            /* verilator lint_on WIDTH */
        end
        state <= STATE_WAIT_ADDRESS;
        AXI_RRESP <= 0;
        AXI_BRESP <= 0;
    end else begin
        mtime <= mtime + 1'b1;
        state <= state_nxt;
        address <= address_nxt;
        AXI_RRESP <= AXI_RRESP_nxt;
        AXI_BRESP <= AXI_BRESP_nxt;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            /* verilator lint_off WIDTH */
            hart_timeri[i] <= (mtimecmp[i] <= mtime);
            /* verilator lint_on WIDTH */
        end
        if(state == STATE_WRITE_DATA) begin
            if(msip_sel) begin
                /* verilator lint_off WIDTH */
                if(AXI_WSTRB[0])
                    hart_swi[address_hart_id] <= AXI_WDATA[0];
                /* verilator lint_on WIDTH */
            end else if(mtimecmp_low_sel) begin
                /* verilator lint_off WIDTH */
                if(AXI_WSTRB[0])
                    mtimecmp[address_hart_id][7:0] <= AXI_WDATA[7:0];
                if(AXI_WSTRB[1])
                    mtimecmp[address_hart_id][15:8] <= AXI_WDATA[15:8];
                if(AXI_WSTRB[2])
                    mtimecmp[address_hart_id][23:16] <= AXI_WDATA[23:16];
                if(AXI_WSTRB[3])
                    mtimecmp[address_hart_id][31:24] <= AXI_WDATA[31:24];
            end else if(mtimecmp_high_sel) begin
                if(AXI_WSTRB[0])
                    mtimecmp[address_hart_id][39:32] <= AXI_WDATA[7:0];
                if(AXI_WSTRB[1])
                    mtimecmp[address_hart_id][47:40] <= AXI_WDATA[15:8];
                if(AXI_WSTRB[2])
                    mtimecmp[address_hart_id][55:48] <= AXI_WDATA[23:16];
                if(AXI_WSTRB[3])
                    mtimecmp[address_hart_id][63:56] <= AXI_WDATA[31:24];
                /* verilator lint_on WIDTH */
            end
        end
    end
end


always @* begin : main_always_comb
    address_nxt = address;
    AXI_AWREADY = 0;
    AXI_ARREADY = 0;
    state_nxt = state;
    AXI_WREADY = 0;
    AXI_BVALID = 0;
    AXI_BRESP_nxt = AXI_BRESP;
    AXI_RRESP_nxt = AXI_RRESP;
    AXI_RVALID = 0;
    AXI_RDATA = 0;
    /* verilator lint_off WIDTH */
    if(msip_sel)
        AXI_RDATA = hart_swi[address_hart_id];
    else if(mtimecmp_high_sel)
        AXI_RDATA = mtimecmp[address_hart_id][63:32];
    else if(mtimecmp_low_sel)
        AXI_RDATA = mtimecmp[address_hart_id][31:0];
    else if(mtime_low_sel)
        AXI_RDATA = mtime[31:0];
    else if(mtime_high_sel)
        AXI_RDATA = mtime[63:32];
    /* verilator lint_on WIDTH */
    case(state)
        STATE_WAIT_ADDRESS: begin
            if(AXI_AWVALID) begin
                address_nxt = AXI_AWADDR; // address
                AXI_AWREADY = 1; // Address write request accepted

                if(AXI_AWADDR[1:0] == 2'b00 // Alligned only
                    && address_nxt_match_any
                    )
                begin
                    state_nxt = STATE_WRITE_DATA;
                    AXI_BRESP_nxt = 2'b00;
                end else begin
                    if(!address_nxt_match_any)
                        AXI_BRESP_nxt = 2'b11;
                    else
                        AXI_BRESP_nxt = 2'b10;
                    state_nxt = STATE_SKIP_WRITE_DATA;
                end
            end else if(AXI_ARVALID) begin
                address_nxt = AXI_ARADDR;
                state_nxt = STATE_OUTPUT_READDATA;
                if(AXI_ARADDR[1:0] == 2'b00
                    && address_nxt_match_any 
                ) begin
                    AXI_RRESP_nxt = 2'b00;
                    AXI_ARREADY = 1;
                end else begin
                    AXI_RRESP_nxt = 2'b10;
                    AXI_ARREADY = 1;
                end
            end
        end
        STATE_WRITE_DATA: begin
            if(AXI_WVALID) begin
                AXI_WREADY = 1;
                state_nxt = STATE_WRITE_RESPOND;
                
                if(mtime_low_sel || mtime_high_sel)
                    AXI_BRESP_nxt = 2'b10/*ADDRESS ERROR*/;
                else
                    AXI_BRESP_nxt = 2'b00/*OKAY*/;
            end
        end
        STATE_OUTPUT_READDATA: begin
            AXI_RVALID = 1;
            if(AXI_RREADY)
                state_nxt = STATE_WAIT_ADDRESS;
        end
        STATE_SKIP_WRITE_DATA: begin
            AXI_WREADY = 1;
            if(AXI_WVALID) begin
                state_nxt = STATE_WRITE_RESPOND;
                `ifdef DEBUG_CLINT
                    if(AXI_BRESP == 0) begin
                        $display("SKIP WRITE DATA with zero BRESP");
                        $finish;
                    end
                `endif
            end
        end
        STATE_WRITE_RESPOND: begin
            AXI_BVALID = 1;
            // BRESP is already set in previous stage
            if(AXI_BREADY) begin
                state_nxt = STATE_WAIT_ADDRESS;
            end
        end
        default: begin
            
        end
    endcase
end



endmodule
