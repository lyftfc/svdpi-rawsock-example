`timescale 1 ns / 1 ps

module sim_top();

import "DPI-C" function bit dpiInitRSContext (input int numSocks);
import "DPI-C" function void dpiDeinitRSContext ();
import "DPI-C" function int dpiInitRawSocket (input string ifname, input bit isProm);
import "DPI-C" function bit dpiDeinitRawSocket (input int rsh);

parameter NUM_SOCK = 2;
parameter DATA_BYTES = 8;
parameter PORT_A = "s1-eth1";
parameter PORT_B = "s1-eth2";

reg clk;
longint cycle;
int	rsid[NUM_SOCK];

initial begin
	clk = 1'b0;
	cycle = 0;
	if (! dpiInitRSContext(NUM_SOCK)) begin
		$display("Failed to initialise DPI socket context.");
		$finish;
	end
	rsid[0] = dpiInitRawSocket(PORT_A, 1'b1);
	rsid[1] = dpiInitRawSocket(PORT_B, 1'b1);
	if (rsid[0] < 0 || rsid[1] < 0) begin
		$display("Failed to initialise socket on given interface.");
		$finish;
	end
	$display("Socked ID: %d, %d", rsid[0], rsid[1]);
end

always #5 clk = ~clk;

logic [DATA_BYTES*8-1:0] data_d;
logic data_v, data_r;
logic [7:0] flags_d;
logic flags_v, flags_r;
logic [DATA_BYTES-1:0] eop_d;
logic eop_v, eop_r;
logic [DATA_BYTES*8-1:0] pb_data_d;
logic pb_data_v, pb_data_r;
logic [7:0] pb_flags_d;
logic pb_flags_v, pb_flags_r;
logic [DATA_BYTES-1:0] pb_eop_d;
logic pb_eop_v, pb_eop_r;

pktunit_axis_feeder port_a_in (
	.clk(clk), .rsh(rsid[0]),
	.data_d(data_d), .data_v(data_v), .data_r(data_r),
	.flags_d(flags_d), .flags_v(flags_v), .flags_r(flags_r),
	.eop_d(eop_d), .eop_v(eop_v), .eop_r(eop_r)
);

pktunit_axis_feeder port_b_in (
	.clk(clk), .rsh(rsid[1]),
	.data_d(pb_data_d), .data_v(pb_data_v), .data_r(pb_data_r),
	.flags_d(pb_flags_d), .flags_v(pb_flags_v), .flags_r(pb_flags_r),
	.eop_d(pb_eop_d), .eop_v(pb_eop_v), .eop_r(pb_eop_r)
);

pktunit_axis_poller port_a_out (
	.clk(clk), .rsh(rsid[0]),
	.data_d(pb_data_d), .data_v(pb_data_v), .data_r(pb_data_r),
	.flags_d(pb_flags_d), .flags_v(pb_flags_v), .flags_r(pb_flags_r),
	.eop_d(pb_eop_d), .eop_v(pb_eop_v), .eop_r(pb_eop_r)
);

pktunit_axis_poller port_b_out (
	.clk(clk), .rsh(rsid[1]),
	.data_d(data_d), .data_v(data_v), .data_r(data_r),
	.flags_d(flags_d), .flags_v(flags_v), .flags_r(flags_r),
	.eop_d(eop_d), .eop_v(eop_v), .eop_r(eop_r)
);

always @ (posedge clk) begin	: axi_monitor
	if (data_v & eop_v & data_r & eop_r)
		$display("[PA] Data: %x, EOP: %b", data_d, eop_d);
	if (pb_data_v & pb_eop_v & pb_data_r & pb_eop_r)
		$display("[PB] Data: %x, EOP: %b", pb_data_d, pb_eop_d);
end

always @ (posedge clk) begin	: cycle_counter
	// $display("Cycle: %d", cycle);
	cycle <= cycle + 1;
	// if (cycle == 20) begin
	// 	dpiDeinitRSContext();
	// 	$finish;
	// end
end

endmodule
