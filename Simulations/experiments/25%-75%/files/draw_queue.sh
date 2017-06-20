#!/bin/sh

gnuplot -persist << EOF
reset
set title "Queue Size"
set xlabel "Simulation Time (s)"
set ylabel "Queue Size in bytes "
set terminal png
set output "queue.png"
plot "queue.tr" using 3:9 notitle with lines; #lp
EOF



