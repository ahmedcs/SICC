#!/bin/sh


k=$(($1 / 2 + 2))

echo "executing gnuplot for throughput file"

for j in `seq 3 $k`
do
gnuplot -persist << EOF
reset
set title "Goodput - Servers"
set xlabel "Server Number"
set ylabel "Goodput Mb/s"
set terminal png
set output "Goodput - Servers $(($j-2)).png"

set yrange [0:$((10000 * 4 / $1))]
unset key

# Retrieve statistical properties
#plot 'thrfile.tr' u 1:3
#min_y = GPVAL_DATA_Y_MIN
#max_y = GPVAL_DATA_Y_MAX

# Retrieve statistical properties
f(x) = mean_y
fit f(x) 'thrfile.tr' u 1:$j via mean_y

stddev_y = sqrt(FIT_WSSR / (FIT_NDF + 1 ))

# Plotting the range of standard deviation with a shaded background
set label 1 gprintf("Mean = %g", mean_y) at 0.2, $(( 10000 / (2 * $1)))
set label 2 gprintf("SD = %g", stddev_y) at 0.7, $(( 10000 / (2 * $1)))
plot mean_y-stddev_y with filledcurves y1=mean_y lt 1 lc rgb "#bbbbdd", \
mean_y+stddev_y with filledcurves y1=mean_y lt 1 lc rgb "#bbbbdd", \
mean_y w l lt 3, 'thrfile.tr' u 1:$j w p pt 7 lt 1 ps 1

EOF
done