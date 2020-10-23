`timescale 1 ns / 1 ps

module sim_top();

import "DPI-C" function bit dpiInitRSContext (input int numSocks);
import "DPI-C" function void dpiDeinitRSContext ();
import "DPI-C" function int dpiInitRawSocket (input string ifname, input bit isProm);
import "DPI-C" function bit dpiDeinitRawSocket (input int rsh);
import "DPI-C" function int dpiRecvFrame (input int rsh, bit isBlk);
import "DPI-C" function bit dpiSendFrame (input int rsh);
import "DPI-C" function byte dpiGetByte (input int rsh);
import "DPI-C" function void dpiPutByte (input int rsh, input byte val);

parameter NUM_SOCK = 1;
parameter DATA_BYTES = 8;

reg clk;
int cycle, rxSize, rxProg;
int	rsid[NUM_SOCK];

initial begin
	clk = 1'b0;
	cycle = 0;
	if (! dpiInitRSContext(NUM_SOCK)) begin
		$display("Failed to initialise DPI socket context.");
		$finish;
	end
	rsid[0] = dpiInitRawSocket("wlx002e2dad6745", 1'b1);
end

always #5 clk = ~clk;

logic [DATA_BYTES*8-1:0] data_d;
logic data_v;
logic data_r;
logic [7:0] flags_d;
logic flags_v;
logic flags_r;
logic [7:0] eop_d;
logic eop_v;
logic eop_r;

pktunit_axis_feeder wlx002_in (
	.clk(clk),
	.rsh(rsid[0]),
	.data_d(data_d),
	.data_v(data_v),
	.data_r(data_r),
	.flags_d(flags_d),
	.flags_v(flags_v),
	.flags_r(flags_r),
	.eop_d(eop_d),
	.eop_v(eop_v),
	.eop_r(eop_r)
);

pktunit_axis_poller wlx002_out (
	.clk(clk),
	.rsh(rsid[0]),
	.data_d(data_d),
	.data_v(data_v),
	.data_r(data_r),
	.flags_d(flags_d),
	.flags_v(flags_v),
	.flags_r(flags_r),
	.eop_d(eop_d),
	.eop_v(eop_v),
	.eop_r(eop_r)
);

always @ (posedge clk) begin	: axi_monitor
	if (data_v & eop_v) begin
		if (data_r & eop_r)
			$display("Data: %x, EOP: %b", data_d, eop_d);
	end
end

always @ (posedge clk) begin	: cycle_counter
	$display("Cycle: %d", cycle);
	cycle <= cycle + 1;
	if (cycle == 20) begin
		dpiDeinitRSContext();
		$finish;
	end
end

endmodule
