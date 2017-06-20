#!/bin/sh

for j in `seq 1 5`
do
gnuplot -persist << EOF
reset
set title "Flow Completion times of patch $j"
set xlabel "Source No."
set ylabel "Time in (ms)"
set terminal png
set output "flowcomp$j.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 4 ]
plot "fcomp$j.tr" using 1:2 notitle with point 
EOF
done

gnuplot -persist << EOF
reset
set title "Average Flow Completion times"
set xlabel "Source No."
set ylabel "Variance in (ms)"
set terminal png
set output "flowcompavg.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompavg.tr" using 1:2 notitle with lp 
EOF


gnuplot -persist << EOF
reset
set title "Flow Completion times Variance"
set xlabel "Source No."
set ylabel "Variance in (ms)"
set terminal png
set output "flowcompvar.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompvar.tr" using 1:2 notitle with lp 
EOF

gnuplot -persist << EOF
reset
set title "Flow Completion times Average-Standard Deviation"
set xlabel "Source No."
set ylabel "Average-Standard Deviation in (ms)"
set terminal png
set output "flowcompavgstd.png"
set xtic 1
set xrange [$(($1/2)) : $(($1 + 1)) ]
set ytic 0.5
set yrange [ 0 : 3 ]
plot "flowcompavgstd.tr" using 1:2:3 notitle with yerrorbars
EOF
