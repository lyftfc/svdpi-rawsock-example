#!/bin/sh

mkdir ip.tmp
cd ip.tmp
unzip ../xilinx_com_hls_EtherSwitch_Top_1_0.zip
mv ./hdl/verilog/*.v ../ip/
mv ./hdl/verilog/*.dat ../
cd ..
rm -rf ip.tmp/