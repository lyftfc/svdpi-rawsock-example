`timescale 1 ns / 1 ps

module pktunit_axis_poller #(
    parameter DATA_BYTES = 8    // 64-bit
) (
    input  bit clk,
    input  int rsh,
    input  logic [DATA_BYTES*8-1:0] data_d,
    input  logic data_v,
    output logic data_r,
    input  logic [7:0] flags_d,
    input  logic flags_v,
    output logic flags_r,
    input  logic [DATA_BYTES-1:0] eop_d,
    input  logic eop_v,
    output logic eop_r
);

import "DPI-C" function bit dpiSendFrame (input int rsh);
import "DPI-C" function void dpiPutByte (input int rsh, input int ofs, input byte val);

logic sReady, mValid, resend;
assign mValid = data_v & flags_v & eop_v;
assign data_r = sReady;
assign flags_r = sReady;
assign eop_r = sReady;

int offset;

initial begin
    sReady = 1'b1;
    resend = 1'b0;
    offset = 0;
end

always @ (posedge clk) begin
    if (sReady && mValid) begin
        int i;
        for (i = 0; i < DATA_BYTES; i++) begin
            if (i == 0 || eop_d[i-1] == 1'b0)
                dpiPutByte(rsh, offset + i, data_d[i*8 +: 8]);
        end
        offset += DATA_BYTES;
        if (|eop_d) begin   // Last PU
            offset = 0;
            if (dpiSendFrame(rsh)) begin
                resend = 1'b0;
                $display("Sent packet to socket %d", rsh);
            end else begin
                sReady = 1'b0;
                resend = 1'b1;
            end
        end
    end else begin
        if (resend) begin
            if (dpiSendFrame(rsh)) begin
                sReady = 1'b1;
                resend = 1'b0;
                $display("Sent packet to socket %d after retry", rsh);
            end else begin
                sReady = 1'b0;
            end
        end
    end
end

endmodule