# set signals {
#     /sim_top/clk
#     /sim_top/data_d
#     /sim_top/pb_data_d
# }
# foreach s $signals {log_wave $s}
log_wave -recursive /
# foreach s $signals {add_wave $s}
# save_wave_config testbench
run all
quit
