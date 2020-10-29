# SystemVerilog DPI Raw Socket Example

Example code for accessing raw (Linux) network socket from 
SystemVerilog code using DPI interface provided by Xilinx's 
xsim simulator.

-----

## Usage

### Running on Host's Interfaces

This example forwards all raw ethernet frames on a specified interface
to the other, and vice versa.

1. Make sure Xilinx's `xsim`, `xvlog`, `xsc` and `xelab` can be 
found in your path. Also requires `make` for automatic building.
2. Find the two network interfaces you want to cross-forward 
(e.g. `eth0` and `wlan0`) using tools such as `ifconfig`. Fill them 
as the values of parameters `PORT_A` and `PORT_B` in `sim_top.sv`. 
Bit 1 for the 2nd parameter of `dpiInitRawSocket()` will put the 
corresponding interface into promiscuous mode.
3. Change to this directory and execute `make`.
4. Execute `sudo make run` to run simulation. A ethernet frame 
will be sniffed from one of the specified interface and forward to 
the other. The simulation runs indefinitely until interrupted by 
`Ctrl^c`. 
5. Alternatively, `sudo make run_gui` starts the Vivado GUI for 
simulation. Or you may run `sudo make run_wave` to have some signals 
logged. Choose the signals by modifying `dump_wave.tcl`.
6. After a `sudo make run_wave` execution, view the waveforms with 
`make view_wave`.

### Running with Mininet

This example creates a network topology of two hosts (h1 and h2) 
connected to a switch (s1) on which the simulation is run. The HDL 
design mixes ethernet frames on s1's two ports hence acts as a switch.

1. On top of the compilation toolchain, Python 2, Mininet and its 
Python extension are required.
2. Make sure that the parameters `PORT_A` and `PORT_B` in `sim_top.sv` 
are `s1-eth1` and `s2-eth2` respectively.
3. Change to this directory and execute `make`.
4. Execute `sudo ./test.py` in this directory. It starts the simulation 
in the background of s1 and gives you the Mininet console. Simulation 
output is written to `xsim-mn-out.log` by default.
5. Try running e.g. `h1 ping h2` or `h1 ssh h2` in Mininet.

-----

## Notes

- Comment out `#define __USE_MISC` in `rawsock.c` to prevent the 
redefinition warning.
- Absolute path to `xsim` is used in `Makefile`, in case the 
toolchain is not in the path of root user. Change it as needed.
- Root privilege is requried for opening raw socket, hence the `sudo`. 
- The raw socket works in sniffer mode, which means the OS kernel 
will still receive the packets. Outgoing packets from OS kernel 
will also be sniffed. To prevent this, run
`sudo iptables -A INPUT -i your_if_name -j DROP`
to block the OS kernel, and 
`sudo iptables -D INPUT -i your_if_name -j DROP`
to restore.
- `make view_wave` requires write permission to `.Xil/`. May need 
to `chown` the directory if it belongs to root due to `sudo`.

### Packet Unit AXI Stream

In this example, HDL modules `pktunit_axis_feeder` and 
`pktunit_axis_poller` calls the DPI socket functions defined in 
`rawsock.c`, puts data onto or polls them from an AXI Stream. The 
format of such an stream ("Packet Unit" AXI Stream) is defined as: 

- **data**: Data bus of `DATA_BYTES` parallel bytes. 8*8=64 bits 
in this example. Carries the packet data, bytes of smaller offsets 
are at the LSB. Bit order in a byte is the same as the bus.
- **flags**: Optional flags associated with a packet unit. Reserved 
for processing inside the HDL design, not used in this example.
- **eop**: End-of-packet indication bit, width of `DATA_BYTES`. Each 
bit corresponds to a byte in **data**. If the bit is set to 1, the 
corresponding byte *is* or *is beyond* the last byte in a packet.