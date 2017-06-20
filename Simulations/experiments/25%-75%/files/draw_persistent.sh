#!/bin/sh

nodes=$1
colnum=$(($nodes + 2))

gnuplot -persist << EOF
reset
set title "Persistent Queue"
set xlabel "Simulation Time (s)"
set ylabel "Queue in bytes"
set terminal png
set output "persistent.png"

plot "mytracefile.tr" using 1:$colnum notitle with lines; #lp
EOF
