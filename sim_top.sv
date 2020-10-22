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

reg clk;
int cycle, rxSize, rxProg;
int	rsid;

initial begin
	clk = 1'b0;
	cycle = 0;
	if (dpiInitRSContext(1) == 1'b0) begin
		$display("Failed to initialise DPI socket context.");
		$finish;
	end
	rsid = dpiInitRawSocket("enp0s31f6", 1'b0);
	if (rsid >= 0) begin
		rxSize = dpiRecvFrame(rsid, 1'b1);
		rxProg = 0;
	end else begin
		$display("Failed to initialise socket.");
		$finish;
	end
end

always #5 clk = ~clk;

always @ (posedge clk) begin
	
	if (rxSize > rxProg) begin
		$display("%d: %H", cycle, dpiGetByte(rsid));
	end else
		$display("%d", cycle);
	cycle <= cycle + 1;
	if (cycle == 20) begin
		dpiDeinitRSContext();
		$finish;
	end
end

endmodule
