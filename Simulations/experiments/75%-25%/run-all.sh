#!/bin/bash

simtime=5

for N in  "80" #"20" "40" "80" "160" #"20" "80" "160" #"50" "100" #"50" "100" #"200" # "10" "25" "50" 
do
for tcpop in   "0" #"0" "1"
do
for psize in  "1460"
do
for qsize in  "83" #"166"
do
for minrto in   "0.2" #"0.0002"
do
for interval in   "0.001" #"0.0005" "0.001" "0.0015" "0.002" "0.0025" "0.003" "0.005" "0.01"
do
for size  in   "0.2" #"0.0" "0.1" "0.2" "0.3" "0.4" "0.5" "0.6" "0.7" 
do
(./run-rwndq.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 0.0005 0.2 > RWNDQ-$(date +%Y-%m-%d.%H.%M.%S).log ) >& RWNDQ-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

(./run-siccq.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 $interval $size > SICCQ-$(date +%Y-%m-%d.%H.%M.%S).log ) >& SICCQ-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

( ./run-dctcp.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 > DCTCP-$(date +%Y-%m-%d.%H.%M.%S).log ) >& DCTCP-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

( ./run-tcp.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 > TCP-$(date +%Y-%m-%d.%H.%M.%S).log ) >& TCP-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

( ./run-tcp-red.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 > TCP-RED-$(date +%Y-%m-%d.%H.%M.%S).log ) >& TCP-RED-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

( ./run-xcp.sh $simtime $N $qsize $psize $minrto $tcpop 0.0005 > XCP-$(date +%Y-%m-%d.%H.%M.%S).log ) >& XCP-ERR-$(date +%Y-%m-%d.%H.%M.%S).log

done
done
done
done
done
done
done
