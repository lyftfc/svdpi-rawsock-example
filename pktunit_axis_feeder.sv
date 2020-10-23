`timescale 1 ns / 1 ps

module pktunit_axis_feeder #(
    parameter DATA_BYTES = 8    // 64-bit
) (
    input  bit clk,
    input  int rsh,
    output logic [DATA_BYTES*8-1:0] data_d,
    output logic data_v,
    input  logic data_r,
    output logic [7:0] flags_d,
    output logic flags_v,
    input  logic flags_r,
    output logic [DATA_BYTES:0] eop_d,
    output logic eop_v,
    input  logic eop_r
);

import "DPI-C" function int dpiRecvFrame (input int rsh, bit isBlk);
import "DPI-C" function byte dpiGetByte (input int rsh);

logic sReady, mValid;
assign sReady = data_r & flags_r & eop_r;
assign data_v = mValid;
assign flags_v = mValid;
assign eop_v = mValid;
assign flags_d = 8'b0;

int avail;

initial begin
    avail = 0;
    mValid = 1'b0;
end

always @ (posedge clk) begin
    if (!mValid || sReady) begin
        if (avail == 0) begin
            avail = dpiRecvFrame(rsh, 1'b1);
            $display("Received %d bytes", avail);
        end
        if (avail == 0) begin
            mValid = 1'b0;
        end else begin
            int i;
            for (i = 0; i < DATA_BYTES; i++) begin
                if (avail - i > 0) begin
                    data_d[i*8 +: 8] = dpiGetByte(rsh);
                    eop_d[i] = (avail - i - 1 == 0) ? 1'b1 : 1'b0;
                end else begin
                    data_d[i*8 +: 8] = 8'b0;
                    eop_d[i] = 1'b1;
                end
            end
            avail = (avail > DATA_BYTES) ? avail - DATA_BYTES : 0;
            mValid = 1'b1;
        end
    end
end

endmodule