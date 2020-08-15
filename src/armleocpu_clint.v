module armleocpu_clint(
    clk, rst_n,
    AXI_AWID, AXI_AWADDR, AXI_AWLEN, AXI_AWSIZE, AXI_AWBURST, AXI_AWVALID, AXI_AWREADY,
    AXI_WDATA, AXI_WSTRB, AXI_WLAST, AXI_WVALID, AXI_WREADY,
    AXI_BID, AXI_BRESP, AXI_BVALID, AXI_BREADY,
    AXI_ARID, AXI_ARADDR, AXI_ARLEN, AXI_ARSIZE, AXI_ARBURST, AXI_ARVALID, AXI_ARREADY,
    AXI_RID, AXI_RDATA, AXI_RRESP, AXI_RLAST, AXI_RVALID, AXI_RREADY,
    hart_swi, hart_timeri
);

    parameter HART_COUNT = 8;

    parameter ID_WIDTH = 8;

    input clk;
    input rst_n;


    // address write bus
    input [ID_WIDTH-1:0]    AXI_AWID;
    input [15:0]            AXI_AWADDR;

    input [7:0]             AXI_AWLEN;
    input [2:0]             AXI_AWSIZE;
    input [1:0]             AXI_AWBURST;

    input                   AXI_AWVALID;
    output                  AXI_AWREADY;


    // Write bus
    input  [31:0]           AXI_WDATA;
    input   [3:0]           AXI_WSTRB;
    input                   AXI_WLAST;
    input                   AXI_WVALID;
    output                  AXI_WREADY;

    // Burst response bus
    output  [ID_WIDTH-1:0]  AXI_BID;
    output  [1:0]           AXI_BRESP;
    output                  AXI_BVALID;
    input                   AXI_BREADY;


    // Address read bus
    input  [ID_WIDTH-1:0]   AXI_ARID;
    input  [15:0]           AXI_ARADDR;
    input   [7:0]           AXI_ARLEN;
    input   [2:0]           AXI_ARSIZE;
    input   [1:0]           AXI_ARBURST;
    input                   AXI_ARVALID;
    output                  AXI_ARREADY;

    // Read data bus
    output [ID_WIDTH-1:0]   AXI_RID;
    output [31:0]           AXI_RDATA;
    output                  AXI_RRESP;
    output                  AXI_RLAST;
    output                  AXI_RVALID;
    input                   AXI_RREADY;


    output [HART_COUNT-1:0] hart_swi;
    output [HART_COUNT-1:0] hart_timeri;



reg [63:0] mtime;

reg state;
reg state_nxt;

reg [(HART_COUNT*64)-1:0] mtimecmp;


reg [15:0] waddress;

always @(posedge clk) begin : main_always_ff
    reg [HART_COUNT:0] i;
    if(!rst_n) begin
        mtime <= 0;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            hart_timeri[i] <= 1'b0;
            mtimecmp[i*64+:64]  <= 64'd0;
        end
    end else begin
        mtime <= mtime + 1'd1;
        state <= state_nxt;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            hart_timeri[i] <= (mtimecmp[i*64+:64] >= mtime);
        end
    end
end


always @* begin : address_nxt_match_logic_always_comb
    address_nxt_match_any = 0;
    
end

always @* begin : main_always_comb
    

    AXI_BID_nxt = AXI_BID;
    address_nxt = address;
    AXI_AWREADY_nxt = 0;
    state_nxt = state;
    AXI_WREADY = 0;
    AXI_BVALID = 0;
    AXI_BRESP_nxt = AXI_BRESP;
    AXI_RRESP_nxt = AXI_RRESP;

    case(state)
        STATE_WAIT_ADDRESS: begin
            if(AXI_AWVALID) begin
                AXI_BID_nxt = AXI_AWID; // ID of transaction mandatory to return in BID, so we should capture it in BID register
                address_nxt = AXI_AWADDR; // address
                AXI_AWREADY_nxt = 1; // Address write request accepted

                if(AXI_AWLEN == 0 && // Only one burst
                    (AXI_AWBURST == 2'b00 || // Fixed
                    AXI_AWBURST == 2'b01) // INCR, WRAP can't be issues with AWLEN = 0
                    && AXI_AWSIZE == 3'b010 //  4 bytes access at once
                    && AXI_AWADDR[1:0] == 2'b00 // Alligned only
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
                AXI_RID_nxt = AXI_ARID;
                address_nxt = AXI_ARADDR;
                state_nxt = STATE_OUTPUT_READDATA;
                if(AXI_ARLEN == 0 &&
                    (AXI_ARBURST == 2'b00 ||
                    AXI_ARBURST == 2'b01)
                    && AXI_ARSIZE == 3'b010
                    && AXI_AWADDR[1:0] == 2'b00
                    && address_nxt_march_any 
                ) begin
                    AXI_RRESP_nxt = 2'b00;
                    AXI_ARREADY_nxt = 1;
                end else begin
                    AXI_RRESP_nxt = 2'b10;
                    AXI_ARREADY_nxt = 1;
                end
            end
        end
        STATE_WRITE_DATA: begin
            if(AXI_WVALID) begin
                AXI_WREADY = 1;
                if(AXI_WLAST) begin
                    state_nxt = STATE_WRITE_RESPOND;
                    AXI_BRESP_nxt = 2'b00/*OKAY*/;
                end
            end
        end
        STATE_OUTPUT_READDATA: begin
            AXI_RLAST = 1;
            AXI_RVALID = 1;
            AXI_RDATA = ;
            if(AXI_RREADY)
                state_nxt = STATE_WAIT_ADDRESS;
        end
        STATE_SKIP_WRITE_DATA: begin
            AXI_WREADY = 1;
            if(AXI_WLAST && AXI_WVALID) begin
                state_nxt = STATE_WRITE_RESPOND_ERROR;
            end
        end
        STATE_WRITE_RESPOND: begin
            AXI_BVALID = 1;
            // BRESP is already set in previous stage
            if(AXI_BREADY) begin
                state_nxt = STATE_WAIT_ADDRESS;
            end
        end
    endcase
end



endmodule