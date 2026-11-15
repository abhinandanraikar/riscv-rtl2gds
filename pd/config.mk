# pd/config.mk - OpenROAD-flow-scripts design configuration for riscv_core
# Used as:  make DESIGN_CONFIG=<project>/pd/config.mk   (see the top Makefile)

export DESIGN_NAME     = riscv_core
export DESIGN_NICKNAME = riscv_core
export PLATFORM        = sky130hd

# project root = one level above this file
PROJ_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)

# Only the synthesizable core. riscv_top.v and the two memories are
# simulation models and must not be listed here.
export VERILOG_FILES = \
    $(PROJ_DIR)/rtl/riscv_core.v \
    $(PROJ_DIR)/rtl/program_counter.v \
    $(PROJ_DIR)/rtl/pipeline_registers.v \
    $(PROJ_DIR)/rtl/control_unit.v \
    $(PROJ_DIR)/rtl/immediate_gen.v \
    $(PROJ_DIR)/rtl/register_file.v \
    $(PROJ_DIR)/rtl/alu.v \
    $(PROJ_DIR)/rtl/hazard_unit.v \
    $(PROJ_DIR)/rtl/forwarding_unit.v \
    $(PROJ_DIR)/rtl/load_store_unit.v

export SDC_FILE = $(PROJ_DIR)/constraints/riscv.sdc

# ---- floorplan ----------------------------------------------------------
export CORE_UTILIZATION  = 40
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN       = 2

# ---- placement ----------------------------------------------------------
export PLACE_DENSITY     = 0.60

# ---- timing repair ------------------------------------------------------
export TNS_END_PERCENT   = 100
