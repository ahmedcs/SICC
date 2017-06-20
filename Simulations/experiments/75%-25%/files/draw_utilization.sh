#!/bin/sh



echo "executing gnuplot for the Mice throughput file"


gnuplot -persist << EOF
reset
set title "bottleneck utilization"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set output "utilization.png"
plot  "thrfile.tr" using 1:2 notitle with lines; #lp
EOF
