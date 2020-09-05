module armleocpu_clint(
    clk, rst_n,
    AXI_AWADDR, AXI_AWVALID, AXI_AWREADY,
    AXI_WDATA, AXI_WSTRB, AXI_WVALID, AXI_WREADY,
    AXI_BRESP, AXI_BVALID, AXI_BREADY,
    AXI_ARADDR, AXI_ARVALID, AXI_ARREADY,
    AXI_RDATA, AXI_RRESP, AXI_RVALID, AXI_RREADY,
    hart_swi, hart_timeri
);

    parameter HART_COUNT = 7; // Valid range: 1 .. 16
    parameter HART_COUNT_WIDTH = 3;

    input clk;
    input rst_n;


    // address write bus
    input [31:0]                AXI_AWADDR;
    input                       AXI_AWVALID;
    output                      AXI_AWREADY;
    


    // Write bus
    input  [31:0]               AXI_WDATA;
    input   [3:0]               AXI_WSTRB;
    input                       AXI_WVALID;
    output                      AXI_WREADY;

    // Burst response bus
    output     [1:0]            AXI_BRESP;
    output                      AXI_BVALID;
    input                       AXI_BREADY;


    // Address read bus
    input  [31:0]               AXI_ARADDR;
    input                       AXI_ARVALID;
    output                      AXI_ARREADY;

    // Read data bus
    output     [31:0]           AXI_RDATA;
    output     [1:0]            AXI_RRESP;
    output                      AXI_RVALID;
    input                       AXI_RREADY;


    output reg [HART_COUNT-1:0] hart_swi;

    output reg [HART_COUNT-1:0] hart_timeri;

reg [63:0] mtime;

reg [63:0] mtimecmp [HART_COUNT-1:0];



wire [31:0] address;
wire write, read;
wire [31:0] write_data;
wire [3:0] write_byteenable;
reg [31:0] read_data;
reg address_error;
reg write_error;

AXI4LiteConverter converter(
    .clk(clk),
    .rst_n(rst_n),

    .AXI_AWADDR(AXI_AWADDR),
    .AXI_AWVALID(AXI_AWVALID),
    .AXI_AWREADY(AXI_AWREADY),

    .AXI_WDATA(AXI_WDATA),
    .AXI_WSTRB(AXI_WSTRB),
    .AXI_WVALID(AXI_WVALID),
    .AXI_WREADY(AXI_WREADY),

    .AXI_BRESP(AXI_BRESP),
    .AXI_BVALID(AXI_BVALID),
    .AXI_BREADY(AXI_BREADY),

    .AXI_ARADDR(AXI_ARADDR),
    .AXI_ARVALID(AXI_ARVALID),
    .AXI_ARREADY(AXI_ARREADY),

    .AXI_RDATA(AXI_RDATA),
    .AXI_RRESP(AXI_RRESP),
    .AXI_RVALID(AXI_RVALID),
    .AXI_RREADY(AXI_RREADY),

    .address(address),
    .write(write),
    .read(read),
    .write_data(write_data),
    .write_byteenable(write_byteenable),
    .read_data(read_data),
    .address_error(address_error),
    .write_error(write_error)
);



 // COMB ->
reg msip_sel,
mtimecmp_sel,
mtime_sel;

wire address_match_any = msip_sel || mtimecmp_sel || mtime_sel;
wire high_sel = address[2];

reg [HART_COUNT_WIDTH-1:0] address_hart_id;
reg hart_id_valid;

always @* begin : address_match_logic_always_comb
    address_hart_id = address[2+HART_COUNT_WIDTH-1:2];
    msip_sel = 0;
    mtimecmp_sel = 0;
    mtime_sel = 0;
    hart_id_valid = 0;
    write_error = 0;
    if(address[31:12] == 0 && address[11:2+HART_COUNT_WIDTH] == 0) begin
        msip_sel = 1;
        address_hart_id = address[2+HART_COUNT_WIDTH-1:2];
        hart_id_valid = {1'b0, address_hart_id} < HART_COUNT;
    end else if((address[31:12] == 4) && address[11:3+HART_COUNT_WIDTH] == 0) begin
        mtimecmp_sel = 1;
        address_hart_id = address[3+HART_COUNT_WIDTH-1:3];
        hart_id_valid = {1'b0, address_hart_id} < HART_COUNT;
    end else if(address == 32'hBFF8 || address == 32'hBFF8 + 4) begin
        mtime_sel = 1;
        hart_id_valid = 1;
        write_error = 1;
    end
    address_error = !hart_id_valid || !address_match_any;
end


always @(posedge clk) begin : main_always_ff
    reg [HART_COUNT_WIDTH:0] i;
    if(!rst_n) begin
        mtime <= 0;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            hart_timeri[i[HART_COUNT_WIDTH-1:0]] <= 1'b0;
            mtimecmp[i[HART_COUNT_WIDTH-1:0]]  <= -64'd1;
        end
    end else begin
        mtime <= mtime + 1'b1;
        for(i = 0; i < HART_COUNT; i = i + 1) begin
            hart_timeri[i[HART_COUNT_WIDTH-1:0]] <= (mtimecmp[i[HART_COUNT_WIDTH-1:0]] <= mtime);
        end
        if(write) begin
            if(msip_sel) begin
                if(write_byteenable[0])
                    hart_swi[address_hart_id] <= write_data[0];
            end else if(mtimecmp_sel) begin
                if(!high_sel) begin
                    if(write_byteenable[0])
                        mtimecmp[address_hart_id][7:0] <= write_data[7:0];
                    if(write_byteenable[1])
                        mtimecmp[address_hart_id][15:8] <= write_data[15:8];
                    if(write_byteenable[2])
                        mtimecmp[address_hart_id][23:16] <= write_data[23:16];
                    if(write_byteenable[3])
                        mtimecmp[address_hart_id][31:24] <= write_data[31:24];
                end else begin
                    if(write_byteenable[0])
                        mtimecmp[address_hart_id][39:32] <= write_data[7:0];
                    if(write_byteenable[1])
                        mtimecmp[address_hart_id][47:40] <= write_data[15:8];
                    if(write_byteenable[2])
                        mtimecmp[address_hart_id][55:48] <= write_data[23:16];
                    if(write_byteenable[3])
                        mtimecmp[address_hart_id][63:56] <= write_data[31:24];
                end
            end
        end

    end
end


always @* begin : read_data_always_comb
    read_data = 0;
    if(msip_sel)
        read_data[0] = hart_swi[address_hart_id];
    else if(mtimecmp_sel) begin
        if(high_sel)
            read_data = mtimecmp[address_hart_id][63:32];
        else
            read_data = mtimecmp[address_hart_id][31:0];
    end else if(mtime_sel)
        if(high_sel)
            read_data = mtime[63:32];
        else
            read_data = mtime[31:0];
end

endmodule
