`timescale 1 ns / 1 ps

module sim_top();

import "DPI-C" function bit dpiInitRSContext (input int numSocks);
import "DPI-C" function void dpiDeinitRSContext ();
import "DPI-C" function int dpiInitRawSocket (input string ifname, input bit isProm);
import "DPI-C" function bit dpiDeinitRawSocket (input int rsh);

parameter NUM_SOCK = 3;
parameter DATA_BYTES = 8;
parameter PORT_A = "s1-eth1";
parameter PORT_B = "s1-eth2";
parameter PORT_C = "s1-eth3";

reg clk, dutNrst;
longint cycle;
int	rsid[NUM_SOCK];

initial begin
	clk = 1'b0;
	dutNrst = 1'b0;
	cycle = 0;
	if (! dpiInitRSContext(NUM_SOCK)) begin
		$display("Failed to initialise DPI socket context.");
		$finish;
	end
	rsid[0] = dpiInitRawSocket(PORT_A, 1'b1);
	rsid[1] = dpiInitRawSocket(PORT_B, 1'b1);
	rsid[2] = dpiInitRawSocket(PORT_C, 1'b1);
	if (rsid[0] < 0 || rsid[1] < 0 || rsid[2] < 0) begin
		$display("Failed to initialise socket on given interface.");
		$finish;
	end
	$display("Socked ID: %d, %d, %d", rsid[0], rsid[1], rsid[2]);
	#2 dutNrst = 1'b1;
end

always #5 clk = ~clk;

logic [DATA_BYTES*8-1:0] data_d;
logic data_v, data_r;
logic [7:0] flags_d;
logic flags_v, flags_r;
logic [DATA_BYTES-1:0] eop_d;
logic eop_v, eop_r;
pktunit_axis_feeder port_a_in (
	.clk(clk), .rsh(rsid[0]),
	.data_d(data_d), .data_v(data_v), .data_r(data_r),
	.flags_d(flags_d), .flags_v(flags_v), .flags_r(flags_r),
	.eop_d(eop_d), .eop_v(eop_v), .eop_r(eop_r)
);

logic [DATA_BYTES*8-1:0] pb_data_d;
logic pb_data_v, pb_data_r;
logic [7:0] pb_flags_d;
logic pb_flags_v, pb_flags_r;
logic [DATA_BYTES-1:0] pb_eop_d;
logic pb_eop_v, pb_eop_r;
pktunit_axis_feeder port_b_in (
	.clk(clk), .rsh(rsid[1]),
	.data_d(pb_data_d), .data_v(pb_data_v), .data_r(pb_data_r),
	.flags_d(pb_flags_d), .flags_v(pb_flags_v), .flags_r(pb_flags_r),
	.eop_d(pb_eop_d), .eop_v(pb_eop_v), .eop_r(pb_eop_r)
);

logic [DATA_BYTES*8-1:0] pc_data_d;
logic pc_data_v, pc_data_r;
logic [7:0] pc_flags_d;
logic pc_flags_v, pc_flags_r;
logic [DATA_BYTES-1:0] pc_eop_d;
logic pc_eop_v, pc_eop_r;
pktunit_axis_feeder port_c_in (
	.clk(clk), .rsh(rsid[2]),
	.data_d(pc_data_d), .data_v(pc_data_v), .data_r(pc_data_r),
	.flags_d(pc_flags_d), .flags_v(pc_flags_v), .flags_r(pc_flags_r),
	.eop_d(pc_eop_d), .eop_v(pc_eop_v), .eop_r(pc_eop_r)
);

logic [DATA_BYTES*8-1:0] data_o_d;
logic data_o_v, data_o_r;
logic [7:0] flags_o_d;
logic flags_o_v, flags_o_r;
logic [DATA_BYTES-1:0] eop_o_d;
logic eop_o_v, eop_o_r;
pktunit_axis_poller port_a_out (
	.clk(clk), .rsh(rsid[0]),
	.data_d(data_o_d), .data_v(data_o_v), .data_r(data_o_r),
	.flags_d(flags_o_d), .flags_v(flags_o_v), .flags_r(flags_o_r),
	.eop_d(eop_o_d), .eop_v(eop_o_v), .eop_r(eop_o_r)
);

logic [DATA_BYTES*8-1:0] pb_data_o_d;
logic pb_data_o_v, pb_data_o_r;
logic [7:0] pb_flags_o_d;
logic pb_flags_o_v, pb_flags_o_r;
logic [DATA_BYTES-1:0] pb_eop_o_d;
logic pb_eop_o_v, pb_eop_o_r;
pktunit_axis_poller port_b_out (
	.clk(clk), .rsh(rsid[1]),
	.data_d(pb_data_o_d), .data_v(pb_data_o_v), .data_r(pb_data_o_r),
	.flags_d(pb_flags_o_d), .flags_v(pb_flags_o_v), .flags_r(pb_flags_o_r),
	.eop_d(pb_eop_o_d), .eop_v(pb_eop_o_v), .eop_r(pb_eop_o_r)
);

logic [DATA_BYTES*8-1:0] pc_data_o_d;
logic pc_data_o_v, pc_data_o_r;
logic [7:0] pc_flags_o_d;
logic pc_flags_o_v, pc_flags_o_r;
logic [DATA_BYTES-1:0] pc_eop_o_d;
logic pc_eop_o_v, pc_eop_o_r;
pktunit_axis_poller port_c_out (
	.clk(clk), .rsh(rsid[2]),
	.data_d(pc_data_o_d), .data_v(pc_data_o_v), .data_r(pc_data_o_r),
	.flags_d(pc_flags_o_d), .flags_v(pc_flags_o_v), .flags_r(pc_flags_o_r),
	.eop_d(pc_eop_o_d), .eop_v(pc_eop_o_v), .eop_r(pc_eop_o_r)
);

EtherSwitch_Top dut (
	.ap_clk		(clk),
	.ap_rst_n	(dutNrst),
	.inStream_0_V_data_V_TDATA		(data_d),
	.inStream_0_V_data_V_TVALID		(data_v),
	.inStream_0_V_data_V_TREADY		(data_r),
	.inStream_1_V_data_V_TDATA		(pb_data_d),
	.inStream_1_V_data_V_TVALID		(pb_data_v),
	.inStream_1_V_data_V_TREADY		(pb_data_r),
	.inStream_2_V_data_V_TDATA		(pc_data_d),
	.inStream_2_V_data_V_TVALID		(pc_data_v),
	.inStream_2_V_data_V_TREADY		(pc_data_r),
	.inStream_0_V_flags_V_TDATA		(flags_d),
	.inStream_0_V_flags_V_TVALID	(flags_v),
	.inStream_0_V_flags_V_TREADY	(flags_r),
	.inStream_1_V_flags_V_TDATA		(pb_flags_d),
	.inStream_1_V_flags_V_TVALID	(pb_flags_v),
	.inStream_1_V_flags_V_TREADY	(pb_flags_r),
	.inStream_2_V_flags_V_TDATA		(pc_flags_d),
	.inStream_2_V_flags_V_TVALID	(pc_flags_v),
	.inStream_2_V_flags_V_TREADY	(pc_flags_r),
	.inStream_0_V_eop_V_TDATA		(eop_d),
	.inStream_0_V_eop_V_TVALID		(eop_v),
	.inStream_0_V_eop_V_TREADY		(eop_r),
	.inStream_1_V_eop_V_TDATA		(pb_eop_d),
	.inStream_1_V_eop_V_TVALID		(pb_eop_v),
	.inStream_1_V_eop_V_TREADY		(pb_eop_r),
	.inStream_2_V_eop_V_TDATA		(pc_eop_d),
	.inStream_2_V_eop_V_TVALID		(pc_eop_v),
	.inStream_2_V_eop_V_TREADY		(pc_eop_r),  
	.outstream_0_V_data_V_TDATA		(data_o_d),
	.outstream_0_V_data_V_TVALID	(data_o_v),
	.outstream_0_V_data_V_TREADY	(data_o_r),
	.outstream_1_V_data_V_TDATA		(pb_data_o_d),
	.outstream_1_V_data_V_TVALID	(pb_data_o_v),
	.outstream_1_V_data_V_TREADY	(pb_data_o_r),
	.outstream_2_V_data_V_TDATA		(pc_data_o_d),
	.outstream_2_V_data_V_TVALID	(pc_data_o_v),
	.outstream_2_V_data_V_TREADY	(pc_data_o_r),
	.outstream_0_V_flags_V_TDATA	(flags_o_d),
	.outstream_0_V_flags_V_TVALID	(flags_o_v),
	.outstream_0_V_flags_V_TREADY	(flags_o_r),
	.outstream_1_V_flags_V_TDATA	(pb_flags_o_d),
	.outstream_1_V_flags_V_TVALID	(pb_flags_o_v),
	.outstream_1_V_flags_V_TREADY	(pb_flags_o_r),
	.outstream_2_V_flags_V_TDATA	(pc_flags_o_d),
	.outstream_2_V_flags_V_TVALID	(pc_flags_o_v),
	.outstream_2_V_flags_V_TREADY	(pc_flags_o_r),
	.outstream_0_V_eop_V_TDATA		(eop_o_d),
	.outstream_0_V_eop_V_TVALID		(eop_o_v),
	.outstream_0_V_eop_V_TREADY		(eop_o_r),
	.outstream_1_V_eop_V_TDATA		(pb_eop_o_d),
	.outstream_1_V_eop_V_TVALID		(pb_eop_o_v),
	.outstream_1_V_eop_V_TREADY		(pb_eop_o_r),
	.outstream_2_V_eop_V_TDATA		(pc_eop_o_d),
	.outstream_2_V_eop_V_TVALID		(pc_eop_o_v),
	.outstream_2_V_eop_V_TREADY		(pc_eop_o_r)
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
