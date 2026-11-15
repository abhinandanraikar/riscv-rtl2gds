#!/bin/sh
# collect_reports.sh - snapshot the key reports and results of the current
# physical-design run into reports/pd/<tag>/ so they survive the next run.
#   sh scripts/collect_reports.sh run01_util40_10ns [flow_variant]
set -e
TAG=${1:?usage: collect_reports.sh <tag>}
PD=pd
VAR=sky130hd/riscv_core/${2:-base}
OUT=reports/pd/$TAG
mkdir -p "$OUT"

cp pd/config.mk constraints/riscv.sdc        "$OUT"/
cp $PD/reports/$VAR/synth_stat.txt           "$OUT"/ 2>/dev/null || true
cp $PD/reports/$VAR/*.rpt                    "$OUT"/ 2>/dev/null || true
cp $PD/reports/$VAR/*.webp $PD/reports/$VAR/*.png "$OUT"/ 2>/dev/null || true
cp $PD/logs/$VAR/*.log                       "$OUT"/ 2>/dev/null || true
cp $PD/reports/$VAR/6_drc_count.rpt $PD/reports/$VAR/6_lvs.lvsdb "$OUT"/ 2>/dev/null || true

# final hand-off files are large: keep them under results/final/<tag>/
FIN=results/final/$TAG
mkdir -p "$FIN"
for f in 6_final.gds 6_final.def 6_final.v 6_final.sdc 6_final.spef 6_final.odb; do
    cp $PD/results/$VAR/$f "$FIN"/ 2>/dev/null || true
done
git rev-parse --short HEAD > "$OUT"/git_commit.txt 2>/dev/null || true
date > "$OUT"/date.txt
echo "reports -> $OUT    final files -> $FIN"
