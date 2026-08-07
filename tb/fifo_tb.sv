`timescale 1ns/1ps

module fifo_tb;

parameter int WIDTH = 4;
parameter int DEPTH = 12;
parameter int ALMOST_FULL_TH  = 2;
parameter int ALMOST_EMPTY_TH = 2;
parameter int CLK_PERIOD = 10;

logic clk;
logic n_rst;
logic we;
logic re;
logic [WIDTH-1:0] wrdata;
logic [WIDTH-1:0] rddata;
logic full;
logic almost_full;
logic empty;
logic almost_empty;

logic [WIDTH-1:0] ref_q [$];
int pass_cnt;
int fail_cnt;
int total_cnt;
int log_fd;

logic cov_write_accept;
logic cov_read_accept;
logic cov_overflow_req;
logic cov_underflow_req;
logic cov_wptr_wrap;
logic cov_rptr_wrap;

fifo #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH),
    .ALMOST_FULL_TH(ALMOST_FULL_TH),
    .ALMOST_EMPTY_TH(ALMOST_EMPTY_TH)
) dut (
    .clk(clk),
    .n_rst(n_rst),
    .we(we),
    .re(re),
    .wrdata(wrdata),
    .rddata(rddata),
    .full(full),
    .almost_full(almost_full),
    .empty(empty),
    .almost_empty(almost_empty)
);

initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;

covergroup fifo_cg;
    option.per_instance = 1;

    cp_reset : coverpoint n_rst {
        bins asserted   = {0};
        bins deasserted = {1};
    }

    cp_req_op : coverpoint {we, re} {
        bins idle   = {2'b00};
        bins read   = {2'b01};
        bins write  = {2'b10};
        bins wr_rd  = {2'b11};
    }

    cp_write_accept : coverpoint cov_write_accept {
        bins rejected = {0};
        bins accepted = {1};
    }

    cp_read_accept : coverpoint cov_read_accept {
        bins rejected = {0};
        bins accepted = {1};
    }

    cp_wrdata : coverpoint wrdata {
        bins values[] = {[0:(1<<WIDTH)-1]};
    }

    cp_count : coverpoint dut.count {
        bins values[] = {[0:DEPTH]};
    }

    cp_wptr : coverpoint dut.wptr {
        bins values[] = {[0:DEPTH-1]};
    }

    cp_rptr : coverpoint dut.rptr {
        bins values[] = {[0:DEPTH-1]};
    }

    cp_full         : coverpoint full;
    cp_empty        : coverpoint empty;
    cp_almost_full  : coverpoint almost_full;
    cp_almost_empty : coverpoint almost_empty;

    cp_overflow_req : coverpoint cov_overflow_req {
        bins hit = {1};
        ignore_bins no_hit = {0};
    }

    cp_underflow_req : coverpoint cov_underflow_req {
        bins hit = {1};
        ignore_bins no_hit = {0};
    }

    cp_wptr_wrap : coverpoint cov_wptr_wrap {
        bins hit = {1};
        ignore_bins no_hit = {0};
    }

    cp_rptr_wrap : coverpoint cov_rptr_wrap {
        bins hit = {1};
        ignore_bins no_hit = {0};
    }

    cx_we_re    : cross we, re;
    cx_we_full  : cross we, full;
    cx_re_empty : cross re, empty;
endgroup

fifo_cg cov = new();

a_count_range : assert property (
    @(posedge clk) disable iff (!n_rst)
    dut.count <= DEPTH
);

a_full_empty_mutex : assert property (
    @(posedge clk) disable iff (!n_rst)
    !(full && empty)
);

a_no_write_when_full : assert property (
    @(posedge clk) disable iff (!n_rst)
    (full && we) |=> $stable(dut.wptr)
);

a_no_read_when_empty : assert property (
    @(posedge clk) disable iff (!n_rst)
    (empty && re) |=> $stable(dut.rptr)
);

a_full_definition : assert property (
    @(posedge clk) disable iff (!n_rst)
    full == (dut.count == DEPTH)
);

a_empty_definition : assert property (
    @(posedge clk) disable iff (!n_rst)
    empty == (dut.count == 0)
);

a_wptr_range : assert property (
    @(posedge clk) disable iff (!n_rst)
    dut.wptr < DEPTH
);

a_rptr_range : assert property (
    @(posedge clk) disable iff (!n_rst)
    dut.rptr < DEPTH
);

task automatic say(input string s);
    $display("%s", s);
    $fdisplay(log_fd, "%s", s);
endtask

function void check_int(input string name, input int got, input int expected);
    bit ok;
    string s;
    ok = (got === expected);
    total_cnt++;
    pass_cnt += ok;
    fail_cnt += !ok;
    s = $sformatf("  [CHECK] %s: got=%0d expected=%0d", name, got, expected);
    $display("%s", s);
    $fdisplay(log_fd, "%s", s);
    assert (ok);
endfunction

function void check_data(
    input string name,
    input logic [WIDTH-1:0] got,
    input logic [WIDTH-1:0] expected
);
    bit ok;
    string s;
    ok = (got === expected);
    total_cnt++;
    pass_cnt += ok;
    fail_cnt += !ok;
    s = $sformatf("  [CHECK] %s: got=0x%0h expected=0x%0h", name, got, expected);
    $display("%s", s);
    $fdisplay(log_fd, "%s", s);
    assert (ok);
endfunction

function void check_flags(input int expected_count);
    check_int("full", full,
              (expected_count == DEPTH));
    check_int("empty", empty,
              (expected_count == 0));
    check_int("almost_full", almost_full,
              (expected_count > (DEPTH - ALMOST_FULL_TH)));
    check_int("almost_empty", almost_empty,
              (expected_count < ALMOST_EMPTY_TH));
endfunction

task automatic do_reset;
    @(negedge clk);
    n_rst  = 1'b0;
    we     = 1'b0;
    re     = 1'b0;
    wrdata = '0;

    cov_write_accept = 1'b0;
    cov_read_accept  = 1'b0;
    cov_overflow_req = 1'b0;
    cov_underflow_req = 1'b0;
    cov_wptr_wrap = 1'b0;
    cov_rptr_wrap = 1'b0;

    repeat (2) begin
        @(posedge clk);
        #1;
        cov.sample();
    end

    ref_q.delete();

    check_int("reset wptr", dut.wptr, 0);
    check_int("reset rptr", dut.rptr, 0);
    check_int("reset count", dut.count, 0);
    check_data("reset rddata", rddata, '0);
    check_flags(0);

    @(negedge clk);
    n_rst = 1'b1;
    @(posedge clk);
    #1;
    cov.sample();
endtask

task automatic fifo_cycle(
    input logic do_write,
    input logic do_read,
    input logic [WIDTH-1:0] data_in
);
    int pre_count;
    bit write_ok;
    bit read_ok;
    logic [WIDTH-1:0] expected_read;

    @(negedge clk);

    pre_count = ref_q.size();
    write_ok  = do_write && (pre_count < DEPTH);
    read_ok   = do_read  && (pre_count > 0);

    if (read_ok)
        expected_read = ref_q[0];
    else
        expected_read = '0;

    we     = do_write;
    re     = do_read;
    wrdata = data_in;

    cov_write_accept = write_ok;
    cov_read_accept  = read_ok;
    cov_overflow_req = do_write && (pre_count == DEPTH);
    cov_underflow_req = do_read && (pre_count == 0);
    cov_wptr_wrap = write_ok && (dut.wptr == DEPTH-1);
    cov_rptr_wrap = read_ok  && (dut.rptr == DEPTH-1);

    @(posedge clk);
    #1;

    if (read_ok)
        check_data("rddata", rddata, expected_read);

    if (read_ok)
        void'(ref_q.pop_front());

    if (write_ok)
        ref_q.push_back(data_in);

    check_int("count", dut.count, ref_q.size());
    check_flags(ref_q.size());

    cov.sample();

    we = 1'b0;
    re = 1'b0;
endtask

initial begin
    int i;
    logic [WIDTH-1:0] random_data;
    logic random_we;
    logic random_re;

    n_rst = 1'b1;
    we = 1'b0;
    re = 1'b0;
    wrdata = '0;
    cov_write_accept = 1'b0;
    cov_read_accept = 1'b0;
    cov_overflow_req = 1'b0;
    cov_underflow_req = 1'b0;
    cov_wptr_wrap = 1'b0;
    cov_rptr_wrap = 1'b0;

    pass_cnt  = 0;
    fail_cnt  = 0;
    total_cnt = 0;

    log_fd = $fopen("results.log", "w");
    assert (log_fd != 0);

    say("");
    say("============================================================");
    say("                FIFO RTL + Verification");
    say("============================================================");
    say($sformatf("WIDTH=%0d, DEPTH=%0d, ALMOST_FULL_TH=%0d, ALMOST_EMPTY_TH=%0d",
                  WIDTH, DEPTH, ALMOST_FULL_TH, ALMOST_EMPTY_TH));

    say("");
    say("--- TEST 1: Reset ---");
    do_reset();

    say("");
    say("--- TEST 2: Empty FIFO Read Protection ---");
    fifo_cycle(1'b0, 1'b1, '0);
    check_int("empty read rptr", dut.rptr, 0);

    say("");
    say("--- TEST 3: Single Write and Read ---");
    fifo_cycle(1'b1, 1'b0, 4'hA);
    fifo_cycle(1'b0, 1'b1, '0);

    say("");
    say("--- TEST 4: Fill FIFO ---");
    do_reset();
    for (i = 0; i < DEPTH; i++)
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);

    check_int("full count", dut.count, DEPTH);
    check_int("full flag", full, 1);

    fifo_cycle(1'b0, 1'b0, '0);

    say("");
    say("--- TEST 5: Full FIFO Write Protection ---");
    fifo_cycle(1'b1, 1'b0, {WIDTH{1'b1}});
    check_int("overflow count unchanged", dut.count, DEPTH);

    say("");
    say("--- TEST 6: Sequential Read and Data Order ---");
    for (i = 0; i < DEPTH; i++)
        fifo_cycle(1'b0, 1'b1, '0);

    check_int("drain count", dut.count, 0);
    check_int("empty flag", empty, 1);

    say("");
    say("--- TEST 7: Simultaneous Read and Write ---");
    do_reset();
    for (i = 0; i < 6; i++)
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);

    for (i = 0; i < 8; i++)
        fifo_cycle(1'b1, 1'b1, 4'h8 + i);

    check_int("simultaneous count stable", dut.count, 6);

    say("");
    say("--- TEST 8: Simultaneous Read/Write When Empty ---");
    do_reset();
    fifo_cycle(1'b1, 1'b1, 4'h5);
    check_int("empty wr/rd count", dut.count, 1);
    fifo_cycle(1'b0, 1'b1, '0);

    say("");
    say("--- TEST 9: Simultaneous Read/Write When Full ---");
    do_reset();
    for (i = 0; i < DEPTH; i++)
        fifo_cycle(1'b1, 1'b0, i + 1);
    fifo_cycle(1'b1, 1'b1, 4'hF);
    check_int("full wr/rd count", dut.count, DEPTH-1);

    say("");
    say("--- TEST 10: Pointer Wraparound ---");
    do_reset();
    for (i = 0; i < DEPTH + 8; i++) begin
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);
        if (ref_q.size() >= 3)
            fifo_cycle(1'b0, 1'b1, '0);
    end
    while (ref_q.size() > 0)
        fifo_cycle(1'b0, 1'b1, '0);

    say("");
    say("--- TEST 11: Almost-Full/Almost-Empty Boundaries ---");
    do_reset();
    for (i = 0; i < DEPTH; i++)
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);
    for (i = 0; i < DEPTH; i++)
        fifo_cycle(1'b0, 1'b1, '0);

    say("");
    say("--- TEST 12: All Input Data Values ---");
    do_reset();
    for (i = 0; i < (1 << WIDTH); i++) begin
        if (ref_q.size() == DEPTH)
            fifo_cycle(1'b0, 1'b1, '0);
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);
    end
    while (ref_q.size() > 0)
        fifo_cycle(1'b0, 1'b1, '0);

    say("");
    say("--- TEST 13: Random Regression (300 cycles) ---");
    do_reset();
    for (i = 0; i < 300; i++) begin
        random_we   = $urandom_range(0, 1);
        random_re   = $urandom_range(0, 1);
        random_data = $urandom_range(0, (1 << WIDTH)-1);
        fifo_cycle(random_we, random_re, random_data);
    end

    say("");
    say("--- TEST 14: Reset During Operation ---");
    for (i = 0; i < 5; i++)
        fifo_cycle(1'b1, 1'b0, i[WIDTH-1:0]);
    do_reset();
    check_int("mid-reset count", dut.count, 0);
    check_int("mid-reset wptr", dut.wptr, 0);
    check_int("mid-reset rptr", dut.rptr, 0);

    say("");
    say("--- TEST 15: Directed Coverage Completion ---");
    fifo_cycle(1'b1, 1'b0, 4'h3);
    fifo_cycle(1'b0, 1'b0, 4'h0);
    fifo_cycle(1'b1, 1'b1, 4'hC);
    fifo_cycle(1'b0, 1'b1, 4'h0);

    say("");
    say("============================================================");
    say("                        TEST SUMMARY");
    say("============================================================");
    say($sformatf("total checks : %0d", total_cnt));
    say($sformatf("PASSED       : %0d", pass_cnt));
    say($sformatf("FAILED       : %0d", fail_cnt));
    say($sformatf("pass rate    : %0.1f%%",
                  100.0 * pass_cnt / total_cnt));

    say("");
    say("============================================================");
    say("                     FUNCTIONAL COVERAGE");
    say("============================================================");
    say($sformatf("overall        : %0.1f%%", cov.get_coverage()));
    say($sformatf("reset          : %0.1f%%", cov.cp_reset.get_coverage()));
    say($sformatf("request op     : %0.1f%%", cov.cp_req_op.get_coverage()));
    say($sformatf("write accept   : %0.1f%%", cov.cp_write_accept.get_coverage()));
    say($sformatf("read accept    : %0.1f%%", cov.cp_read_accept.get_coverage()));
    say($sformatf("wrdata         : %0.1f%%", cov.cp_wrdata.get_coverage()));
    say($sformatf("count          : %0.1f%%", cov.cp_count.get_coverage()));
    say($sformatf("wptr           : %0.1f%%", cov.cp_wptr.get_coverage()));
    say($sformatf("rptr           : %0.1f%%", cov.cp_rptr.get_coverage()));
    say($sformatf("full           : %0.1f%%", cov.cp_full.get_coverage()));
    say($sformatf("empty          : %0.1f%%", cov.cp_empty.get_coverage()));
    say($sformatf("almost_full    : %0.1f%%", cov.cp_almost_full.get_coverage()));
    say($sformatf("almost_empty   : %0.1f%%", cov.cp_almost_empty.get_coverage()));
    say($sformatf("overflow req   : %0.1f%%", cov.cp_overflow_req.get_coverage()));
    say($sformatf("underflow req  : %0.1f%%", cov.cp_underflow_req.get_coverage()));
    say($sformatf("wptr wrap      : %0.1f%%", cov.cp_wptr_wrap.get_coverage()));
    say($sformatf("rptr wrap      : %0.1f%%", cov.cp_rptr_wrap.get_coverage()));
    say($sformatf("we x re        : %0.1f%%", cov.cx_we_re.get_coverage()));
    say($sformatf("we x full      : %0.1f%%", cov.cx_we_full.get_coverage()));
    say($sformatf("re x empty     : %0.1f%%", cov.cx_re_empty.get_coverage()));
    say("============================================================");

    say($sformatf("result fail count       : %0d", fail_cnt));
    say($sformatf("functional coverage     : %0.1f%%", cov.get_coverage()));
    assert (fail_cnt == 0);
    assert (cov.get_coverage() >= 99.999);

    $fclose(log_fd);

    $finish;
end

endmodule
