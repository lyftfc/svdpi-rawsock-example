
SV_SRCS = sim_top.sv pktunit_axis_feeder.sv pktunit_axis_poller.sv
C_SRCS = rawsock.c
TOP_MOD = sim_top

XSIM_WD = xsim.dir
XSC_WD = work
XSIM_WCFG = testbench.wcfg
XSIM_SNAPSHOT = $(XSC_WD).$(TOP_MOD)
SIM_BINARY = $(XSIM_WD)/$(XSIM_SNAPSHOT)/xsimk
ANALYSE_OUT = $(addprefix $(XSIM_WD)/$(XSC_WD)/, ${SV_SRCS:.sv=.sdb})
DPI_BINARY = $(XSIM_WD)/$(XSC_WD)/xsc/dpi.so
XIL_PATH = /tools/Xilinx/Vivado/2020.1/bin

sim: $(SIM_BINARY)

$(SIM_BINARY): $(ANALYSE_OUT) $(DPI_BINARY)
	$(XIL_PATH)/xelab $(TOP_MOD) -sv_lib dpi -debug typical

$(XSIM_WD)/$(XSC_WD)/%.sdb: %.sv
	$(XIL_PATH)/xvlog -svlog $<

$(DPI_BINARY): $(C_SRCS)
	$(XIL_PATH)/xsc $(C_SRCS)

run: sim
	$(XIL_PATH)/xsim $(XSIM_SNAPSHOT) -R

run_gui: sim
	$(XIL_PATH)/xsim $(XSIM_SNAPSHOT) -g

run_wave: sim
	$(XIL_PATH)/xsim $(XSIM_SNAPSHOT) -t dump_wave.tcl

view_wave:
	if [ ! -f "$(XSIM_WCFG)" ]; then echo "No waveform to view."; exit 1; fi
	$(XIL_PATH)/vivado -source view_wave.tcl

clean:
	rm -rf *.jou *.log *.pb *.wdb *.wcfg $(XSIM_WD)/ .Xil/

.PHONY: clean run run_gui run_wave view_wave
