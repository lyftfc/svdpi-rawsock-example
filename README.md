# SystemVerilog DPI Raw Socket Example

Example code for accessing raw (Linux) network socket from 
SystemVerilog code using DPI interface provided by Xilinx's 
xsim simulator.

----

## Usage
1. Make sure Xilinx's `xsim`, `xvlog`, `xsc` and `xelab` can be 
found in your path. Also requires `make` for automatic building.
2. Find the network interface you want to capture (e.g. `eth0`) 
using tools such as `ifconfig`. Fill it as the 1st parameter for 
function call `dpiInitRawSocket()` in `sim_top.sv`.
3. Change to this directory and execute `make`.
4. Execute `sudo make run` to run simulation. A ethernet frame 
will be sniffed from the specified interface and the first several 
bytes will be printed. Alternatively, `sudo make run_gui` gives 
the Vivado GUI for waveform viewing.

## Notes
- Comment out `#define __USE_MISC` in `rawsock.c` to prevent 
redefinition warning.
- Absolute path to `xsim` is used for `make run`, in case the 
toolchain is not in the path of root user. Change it as needed.
- Root privilege is requried for opening raw socket, hence the 
`sudo`. (Also required for `make clean`.)
- The raw socket works in sniffer mode, which means the OS kernel 
will still receive the packets. Outgoing packets from OS kernel 
will also be sniffed. To prevent this, run
`sudo iptables -A INPUT -i your_if_name -j DROP`
to block the OS kernel, and 
`sudo iptables -D INPUT -i your_if_name -j DROP`
to restore.