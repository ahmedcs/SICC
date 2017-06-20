#!/bin/sh



echo "executing gnuplot for the Mice throughput file"

nodenum=$(( $1 / 2)) 

numinfig=$nodenum
totalservers=$nodenum
end=$(($totalservers/$numinfig - 1))
for j in `seq 0 $end`
do
k1=$(($j*$numinfig+3));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "INST Goodput - Servers $(($k1-2))-$(($k2-2))"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set output "INST - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "thrfile.tr" using 1:i notitle with lines; #lp
EOF

done


for j in `seq 0 $end`
do
k1=$(($nodenum + $j*$numinfig +3));
k2=$(($k1+$numinfig-1)); 
gnuplot -persist << EOF
reset
set title "INST Goodput - Servers $(($k1-2))-$(($k2-2))"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set output "INST - Servers $(($k1-1))-$(($k2-1)).png"
title(n)  =  sprintf("s_%d", n-1)
plot for [i=$k1:$k2] "thrfile.tr" using 1:i notitle with lines; #lp
EOF

done


gnuplot -persist << EOF
reset
set title "Total Goodput (Utilization)"
set xlabel "Simulation Time (s)"
set ylabel "Goodput Mb/s "
set terminal png
set output "Total Goodput (Utilization).png"
plot "thrfile.tr" using 1:2 notitle with lines; #lp