# riscv_rtl2gds

RV32I 5-stage pipelined core (`riscv_core`) taken from RTL to GDSII on SKY130 HD
with Icarus Verilog, Verilator, Yosys and OpenROAD-flow-scripts.

    make help        # list every target
    make lint        # Verilator lint of the core
    make sim-all     # directed tests
    make random      # random programs against the Python reference model
    make pd          # full RTL-to-GDSII run (needs ORFS_DIR)
    make sta         # post-route timing

Run log: docs/runlog.md. Curated reports of each run: reports/pd/<tag>/.
