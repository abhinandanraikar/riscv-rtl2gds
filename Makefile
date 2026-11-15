# Makefile - one entry point for every step of the project
# Run every target from the project root (~/riscv_rtl2gds).

# ---- settings you may override on the command line ----------------------
ORFS_DIR ?= $(HOME)/OpenROAD-flow-scripts
TEST     ?= test_all
FLOW_VARIANT ?= base
OPENROAD ?= openroad
PLATFORM := sky130hd
DESIGN   := riscv_core

CORE_RTL := rtl/riscv_core.v rtl/program_counter.v rtl/pipeline_registers.v \
            rtl/control_unit.v rtl/immediate_gen.v rtl/register_file.v \
            rtl/alu.v rtl/hazard_unit.v rtl/forwarding_unit.v rtl/load_store_unit.v
SIM_RTL  := $(CORE_RTL) rtl/riscv_top.v rtl/instruction_memory.v rtl/data_memory.v

SKY_LIB  := $(ORFS_DIR)/flow/platforms/$(PLATFORM)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
PD_RUN   := pd/results/$(PLATFORM)/$(DESIGN)/$(FLOW_VARIANT)
ORFS_MAKE = $(MAKE) -C $(ORFS_DIR)/flow DESIGN_CONFIG=$(CURDIR)/pd/config.mk \
            WORK_HOME=$(CURDIR)/pd FLOW_VARIANT=$(FLOW_VARIANT)

.PHONY: help sw lint sim sim-all wave sim-verilator random synth synth-sky130 \
        pd pd-synth pd-floorplan pd-place pd-cts pd-route pd-finish pd-drc pd-lvs \
        gui-floorplan gui-place gui-cts gui-route gui-final klayout sta \
        collect clean clean-pd

help:
	@grep -E '^[a-z][a-z0-9-]*:.*##' Makefile | sed 's/:.*##/\t/' | expand -t 16

# ---- software -----------------------------------------------------------
sw:              ## assemble the test programs in sw/ into .hex files
	$(MAKE) -C sw

# ---- RTL checks ---------------------------------------------------------
lint:            ## Verilator lint of the synthesizable core
	verilator --lint-only -Wall -Wno-DECLFILENAME --top-module $(DESIGN) $(CORE_RTL)

sim: sw          ## simulate one program:  make sim TEST=sort
	@mkdir -p results/sim reports/sim
	iverilog -g2005 -Wall -Wno-timescale -o results/sim/$(TEST).vvp \
	    -P riscv_tb.INIT_FILE=\"sw/build/$(TEST).hex\" tb/riscv_tb.v $(SIM_RTL)
	vvp -n results/sim/$(TEST).vvp | tee reports/sim/$(TEST).log

sim-all: sw      ## simulate every program in sw/ and print a summary
	@mkdir -p reports/sim
	@for t in $(basename $(notdir $(wildcard sw/*.S))); do \
	    $(MAKE) --no-print-directory sim TEST=$$t > /dev/null; \
	    grep -E "PASS|FAIL" reports/sim/$$t.log; \
	done | tee reports/sim/summary.log
	@! grep -q FAIL reports/sim/summary.log

wave: sw         ## simulate with a VCD dump and open GTKWave
	@mkdir -p results/sim
	iverilog -g2005 -o results/sim/$(TEST).vvp \
	    -P riscv_tb.INIT_FILE=\"sw/build/$(TEST).hex\" tb/riscv_tb.v $(SIM_RTL)
	vvp -n results/sim/$(TEST).vvp +vcd
	gtkwave results/sim/riscv_tb.vcd &

sim-verilator: sw  ## same testbench compiled with Verilator
	@mkdir -p results/sim
	verilator --binary --timing -Wno-fatal --top-module riscv_tb \
	    -GINIT_FILE=\"sw/build/$(TEST).hex\" -Mdir results/sim/obj_dir tb/riscv_tb.v $(SIM_RTL)
	./results/sim/obj_dir/Vriscv_tb

random:          ## 200 random programs against the Python reference model
	@mkdir -p reports/sim
	python3 scripts/random_test.py 200 400 | tee reports/sim/random.log

# ---- stand-alone synthesis (learning / quick area checks) ---------------
synth:           ## generic Yosys synthesis, no technology library
	@mkdir -p results/synth reports/synth
	yosys -q -l reports/synth/generic.log scripts/synth_generic.ys
	@grep -A60 "=== riscv_core ===" reports/synth/generic_stat.rpt | head -40

synth-sky130:    ## Yosys synthesis mapped to SKY130 HD cells
	@mkdir -p results/synth reports/synth
	LIB=$(SKY_LIB) yosys -q -l reports/synth/sky130.log -c scripts/synth_sky130.tcl
	@grep -E "Number of cells|Chip area" reports/synth/sky130_stat.rpt

# ---- physical design through OpenROAD-flow-scripts ----------------------
pd:              ## complete RTL-to-GDSII run
	$(ORFS_MAKE)
pd-synth:        ## ORFS stage 1: synthesis
	$(ORFS_MAKE) synth
pd-floorplan:    ## ORFS stage 2: floorplan, IO pins, tap cells, PDN
	$(ORFS_MAKE) floorplan
pd-place:        ## ORFS stage 3: global + detailed placement
	$(ORFS_MAKE) place
pd-cts:          ## ORFS stage 4: clock tree synthesis
	$(ORFS_MAKE) cts
pd-route:        ## ORFS stage 5: global + detailed routing
	$(ORFS_MAKE) route
pd-finish:       ## ORFS stage 6: fill, extraction, final reports, GDSII
	$(ORFS_MAKE) finish
pd-drc:          ## KLayout DRC on the final GDSII
	$(ORFS_MAKE) drc
pd-lvs:          ## KLayout LVS on the final GDSII
	$(ORFS_MAKE) lvs

gui-floorplan:   ## open the floorplan in the OpenROAD GUI
	$(ORFS_MAKE) gui_floorplan
gui-place:       ## open the placed design
	$(ORFS_MAKE) gui_place
gui-cts:         ## open the design after CTS
	$(ORFS_MAKE) gui_cts
gui-route:       ## open the routed design
	$(ORFS_MAKE) gui_route
gui-final:       ## open the final design
	$(ORFS_MAKE) gui_final

klayout:         ## open the final GDSII in KLayout
	klayout -l $(ORFS_DIR)/flow/platforms/$(PLATFORM)/$(PLATFORM).lyp $(PD_RUN)/6_final.gds &

sta:             ## stand-alone sign-off style STA on the final netlist + SPEF
	@mkdir -p reports/sta
	LIB=$(SKY_LIB) RUN=$(PD_RUN) $(OPENROAD) -no_init -exit scripts/sta.tcl \
	    | tee reports/sta/sta.log

# ---- housekeeping -------------------------------------------------------
collect:         ## copy the key reports of the current run:  make collect TAG=run01
	sh scripts/collect_reports.sh $(TAG) $(FLOW_VARIANT)

clean:           ## remove simulation and stand-alone synthesis outputs
	rm -rf results/sim results/synth reports/sim reports/synth sw/build

clean-pd:        ## remove every physical-design output of this design
	$(ORFS_MAKE) clean_all
