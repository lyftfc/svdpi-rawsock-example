
SV_SRCS = sim_top.sv pktunit_axis_feeder.sv pktunit_axis_poller.sv
C_SRCS = rawsock.c
TOP_MOD = sim_top

XSIM_WD = xsim.dir
XSC_WD = work
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

clean:
	rm -rf *.jou *.log *.pb *.wdb $(XSIM_WD)/ .Xil/

.PHONY: clean run run_gui
