`timescale 1 ns / 1 ps

module sim_top();

import "DPI-C" function bit dpiInitRawSocket (input string ifname, input bit isProm);
import "DPI-C" function bit dpiDeinitRawSocket ();
import "DPI-C" function int dpiRecvFrame ();
import "DPI-C" function bit dpiSendFrame ();
import "DPI-C" function byte dpiGetByte ();
import "DPI-C" function void dpiPutByte (input byte val); 

reg clk, rawSockReady;
integer cycle, rxSize, rxProg;
initial begin
	clk = 1'b0;
	cycle = 0;
	rawSockReady = dpiInitRawSocket("enp0s31f6", 1'b1);
	if (rawSockReady) begin
		rxSize = dpiRecvFrame();
		rxProg = 0;
	end else begin
		$display("Failed to initialise socket.");
		$finish;
	end
end

always #5 clk = ~clk;

always @ (posedge clk) begin
	
	if (rxSize > rxProg) begin
		$display("%d: %H", cycle, dpiGetByte());
	end else
		$display("%d", cycle);
	cycle <= cycle + 1;
	if (cycle == 20) begin
		dpiDeinitRawSocket();
		$finish;
	end
end

endmodule
