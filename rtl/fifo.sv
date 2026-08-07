module fifo #(
    parameter int WIDTH = 4,
    parameter int DEPTH = 12,
    parameter int ALMOST_FULL_TH  = 2,
    parameter int ALMOST_EMPTY_TH = 2,
    parameter int POINTER_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
)(
    input  logic                 clk,
    input  logic                 n_rst,
    input  logic                 we,
    input  logic                 re,
    input  logic [WIDTH-1:0]     wrdata,
    output logic [WIDTH-1:0]     rddata,
    output logic                 full,
    output logic                 almost_full,
    output logic                 empty,
    output logic                 almost_empty
);

localparam int COUNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);

logic [WIDTH-1:0] ram [0:DEPTH-1];

logic [POINTER_W-1:0] wptr;
logic [POINTER_W-1:0] rptr;
logic [POINTER_W-1:0] next_wptr;
logic [POINTER_W-1:0] next_rptr;

logic [COUNT_W-1:0] count;

logic write_accept;
logic read_accept;

assign write_accept = we && !full;
assign read_accept  = re && !empty;

assign full  = (count == DEPTH);

assign empty = (count == 0);

assign almost_full = (count > (DEPTH - ALMOST_FULL_TH));

assign almost_empty = (count < ALMOST_EMPTY_TH);

always_comb begin
    if (wptr == DEPTH-1)
        next_wptr = '0;
    else
        next_wptr = wptr + 1'b1;

    if (rptr == DEPTH-1)
        next_rptr = '0;
    else
        next_rptr = rptr + 1'b1;
end

always_ff @(posedge clk) begin
    if (!n_rst) begin

        wptr   <= '0;
        rptr   <= '0;
        count  <= '0;
        rddata <= '0;
    end
    else begin

        if (write_accept) begin
            ram[wptr] <= wrdata;
            wptr      <= next_wptr;
        end

        if (read_accept) begin
            rddata <= ram[rptr];
            rptr   <= next_rptr;
        end

        unique case ({write_accept, read_accept})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
        endcase
    end
end

endmodule
