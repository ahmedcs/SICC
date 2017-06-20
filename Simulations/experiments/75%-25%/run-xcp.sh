#!/bin/bash

simT=$1
nodes=$2
qsize=$3
psize=$4
minrto=$5
tcpopt=$6
sample=$7

ROOT_DIR=`pwd`
TRACES_DIR=$ROOT_DIR/files/xcp
SCRIPTS_DIR=$ROOT_DIR/files
#BUILD_DIR=$ROOT_DIR/build

#exec > >(tee $TRACES_DIR/logfile.txt)

# NOTE: this must match between ./run and ./scripts/postProcessTraceFiles.sh
RESULTS_DIR_PREFIX=simulation


#rm -rf $TRACES_DIR/$RESULTS_DIR_PREFIX*



    STARTTIME=$(date +%s)
    RESULTS_DIR=$TRACES_DIR/$RESULTS_DIR_PREFIX-simT$simT-N$nodes-Q$qsize-P$psize-MRTO$minrto-TCP$tcpopt-Sample$sample-$(date +%Y-%m-%d.%H.%M.%S)

    cd $SCRIPTS_DIR
    echo ns sim-source.tcl $simT XCP XCP $nodes $qsize $psize $minrto $tcpopt $sample 
    ns sim-source.tcl $simT XCP XCP $nodes $qsize $psize $minrto $tcpopt $sample #> $TRACES_DIR/sim.log
    errorCode=$?
    if [ "$errorCode" -ne 0 ]
    then
        echo "ERROR: Stopping because NS returned error code $errorCode"
	exit -1
    fi
    cd $ROOT_DIR

    # Simulation time calculation
    ENDTIME=$(date +%s)
    DIFF=$(( $ENDTIME - $STARTTIME ))
    DIFF=$(( $DIFF / 60 ))
    echo "Simulation time: $DIFF minutes"

     echo
    echo "Moving trace files into subdirectory..."
    mkdir -p $RESULTS_DIR
    mv -f $SCRIPTS_DIR/*.nam $RESULTS_DIR/
    mv -f $SCRIPTS_DIR/*.tr $RESULTS_DIR/
    cp -f $SCRIPTS_DIR/*.sh $RESULTS_DIR/
    cp -f $SCRIPTS_DIR/*.py $RESULTS_DIR/


echo "Done with all simulations. Now generating the graphs"
 
 cd $RESULTS_DIR/
./draw_queue.sh 
 ./draw_drop.sh $(($nodes * 2)) 4
 ./inst_goodput.sh $nodes
 ./draw_persistent.sh $(($nodes * 2)) 
 ./draw_utilization.sh
  ./flowcompletion.py out.tr $nodes 
 ./draw_fcomp.sh $nodes 
 ./goodput.sh $nodes

mv -f $ROOT_DIR/*.log $RESULTS_DIR/

