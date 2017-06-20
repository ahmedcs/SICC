set simulationTime [lindex $argv 0]
set tcptype [lindex $argv 1]
set qtype [lindex $argv 2]
set N [lindex $argv 3]
set B [lindex $argv 4]
set packetSize  [lindex $argv 5]
set minrto  [lindex $argv 6]
set tcpopt [lindex $argv 7] 
set sample [lindex $argv 8] 


#########################TCP####################################
set switchAlg $qtype
set enableNAM 0
set enabletr 1

set neleph [expr int(floor($N/4))]
set nmice [expr $N-$neleph]

set RTT 0.0001
set K 15
set qpacketSize [expr $packetSize + 40]

Agent/TCP set tcpTick_ 0.00001
Agent/TCP set packetSize_ $packetSize
Agent/TCP set minrto_ $minrto ; # minRTO = 200us
#Agent/TCP set maxrto_ 2
Agent/TCP set delay_growth_ false ;	# default changed on 2001/5/17.
Agent/TCP set rtxcur_init_ [expr $RTT * 3]

if {$tcpopt == "1"} {
	set sourceAlg DC-TCP-Sack
	set ackRatio 1
	Agent/TCP/FullTcp set segsperack_ $ackRatio; 
	Agent/TCP/FullTcp set spa_thresh_ 3000;
	Agent/TCP/FullTcp set interval_ [expr 4 * $RTT] ; #0.0004; #delayed ACK interval = 40ms
} else {
	set sourceAlg DC-TCP-Newreno
	Agent/TCP/FullTcp set interval_ 0.0;  #delayed ACK interval = 40ms
	#Agent/TCP/FullTcp set nodelay_ true;  #delayed ACK interval = 40ms
	
}

if {$tcptype == "XCP"} {
	 set sourceAlg DC-TCP-XCP
	  #set switchAlg XCP
}

if {$tcptype == "TCP" || $tcptype == "DCTCP" || $tcptype == "XCP"} {
Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
#Agent/TCP/FullTcp set ecn_syn_ true
#Agent/TCP/FullTcp set ecn__syn_next_ true
#Agent/TCP/FullTcp set ecn_syn_wait_ true 
	if {$tcptype == "DCTCP"} {		
		Agent/TCP set dctcp_ true
		Agent/TCP set dctcp_g_ 0.0625
		#Agent/TCP set rtxcur_init_ 0.001 ;
		
	}
}

#Agent/TCP set window_ 43
Agent/TCP set window_ 1256
Agent/TCP set slow_start_restart_ false
Agent/TCP set windowOption_ 0
if {$tcpopt == 1} {
	#Agent/TCP set window_ 1256
	#Agent/TCP set slow_start_restart_ false
	#Agent/TCP set windowOption_ 0
}



#########################FullTCP###################################
Agent/TCP/FullTcp set segsize_ $packetSize


#########################DCTCP###################################

#########################TCP Agent Choice####################################
if {$tcptype == "RTCP"} {
	Agent/TCP set use_rwnd_ 1
	Agent/TCP/FullTcp set use_rwnd_ 1
	Agent/TCP set ZW_Timeout_ 0.0005;
	Agent/TCP/FullTcp set ZW_Timeout_ 0.0005;


}

#########################RWNDQ####################################
if {$qtype == "DropTail"} {

Queue/DropTail set queue_in_bytes_ true
Queue/DropTail set mean_pktsize_ $qpacketSize

}

if {$qtype == "DropTail/RWNDQ"} {

set flowupdate [lindex $argv 9] 
set queuefact [lindex $argv 10]

Queue/DropTail/RWNDQ set queue_in_bytes_ true
Queue/DropTail/RWNDQ set flowupdateinterval_ $flowupdate
Queue/DropTail/RWNDQ set queuefactor_ $queuefact
Queue/DropTail/RWNDQ set maxnum_ [expr $N + 1]
Queue/DropTail/RWNDQ set mean_pktsize_ $qpacketSize
}

if {$qtype == "DropTail/SICC"} {

set flowupdate [lindex $argv 9] 
set queuefact [lindex $argv 10]

Queue/DropTail/SICC set queue_in_bytes_ true
Queue/DropTail/SICC set flowupdateinterval_ $flowupdate
Queue/DropTail/SICC set queuefactor_ $queuefact
Queue/DropTail/SICC set maxnum_ [expr $N + 1]
Queue/DropTail/SICC set mean_pktsize_ $qpacketSize
#Queue/DropTail/SICC set incastonly_ false
}

#########################RED####################################
#Queue/RED set limit_ 150
if {$qtype == "RED"} {
Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ false
Queue/RED set mean_pktsize_ $qpacketSize
#Queue/RED set maxthresh_ [expr $K]
Queue/RED set setbit_ true
	if {$tcptype == "DCTCP"} {
	    puts "setting RED-DCTCP"
            Queue/RED set gentle_ false
	    #Queue/RED set queue_in_bytes_ true
	    #Queue/RED set setbit_ true
            Queue/RED set q_weight_ 1.0
            Queue/RED set mark_p_ 1.0
            Queue/RED set thresh_ [expr $K]
            Queue/RED set maxthresh_ [expr $K]
	}
        if { $tcptype == "XCP"} {
			Queue/RED set thresh_ [expr 0.6 * $qsize]
			Queue/RED set maxthresh_ [expr 0.8 * $qsize]
			Queue/RED set q_weight_ 0.001
			Queue/RED set linterm_ 10
			#Queue/RED set bytes_ false ;
			#Queue/RED set queue_in_bytes_ false ;
			Agent/TCP set old_ecn_ true
			Queue/RED set setbit_     true
	}
}



##########################setting TCP and AQM##################################
for {set i 0} {$i < $N} {incr i} {
	    set totaldrops($i) 0
}



set startMeasurementTime 0.11
set stopMeasurementTime [expr $simulationTime - 0.1]
set flowClassifyTime $sample

set lineRate 1Gb
set inputLineRate 1Gb
 
set traceSamplingInterval $sample
set throughputSamplingInterval [expr $sample * 5]
set dropSamplingInterval $sample


set ns [new Simulator]

if {$enableNAM != 0} {
    set namfile [open out.nam w]
    $ns namtrace-all $namfile
}

if {$enabletr != 0} {
    set trfile [open out.tr w]
    $ns trace-all $trfile
}

set mytracefile [open mytracefile.tr w]
set mytracefile1 [open rwndqtracefile.tr w]
set throughputfile [open thrfile.tr w]
set dropfile [open dropfile.tr w]
set dfile [open source-drop.tr w]

proc finish {} {
        global ns enableNAM enabletr namfile mytracefile mytracefile1 throughputfile qfile dropfile dfile trfile
        $ns flush-trace
        close $mytracefile
        close $mytracefile1
        close $throughputfile
	close $dropfile
	#close $qfile
        if {$enableNAM != 0} {
	    close $namfile
	    exec nam out.nam &
	}
	if {$enabletr != 0} {
   		close $trfile
	}
	

	close $dfile
	exit 0
}

set meanq 0
set oldmeanq 0
set count 0
set oldbdepartures 0

proc myTrace {file} {
    global ns N traceSamplingInterval tcp qfile MainLink nbow nclient packetSize enableBumpOnWire tcptype meanq oldmeanq count oldbdepartures
    
    set now [$ns now]
    
    for {set i 0} {$i < $N} {incr i} {
	set cwnd($i) [$tcp($i) set cwnd_]	
    }
    
    $qfile instvar barrivals_ bdepartures_ pdrops_ bdrops_
    puts -nonewline $file "$now $cwnd(0)"
    for {set i 1} {$i < $N} {incr i} {
	puts -nonewline $file " $cwnd($i)"
    }
    
	if {$tcptype == "RTCP"} {
	    for {set i 0} {$i < $N} {incr i} {
		set wnd($i) [$tcp($i) set window_]
		puts -nonewline $file " $wnd($i)"
	    }
	}
	if {$tcptype == "DCTCP"} {
	    for {set i 0} {$i < $N} {incr i} {
		set dctcp_alpha($i) [$tcp($i) set dctcp_alpha_]
		puts -nonewline $file " $dctcp_alpha($i)"
	    }
	}

#if {$tcptype == "TCP"} {
#    for {set i 0} {$i < $N} {incr i} {
#	puts -nonewline $file " 0"
#    }
#}

#if {$tcptype == "XCP"} {
#    for {set i 0} {$i < $N} {incr i} {
#	puts -nonewline $file " 0"
#    }
#}
 
     #puts -nonewline $file " [expr $parrivals_-$pdepartures_-$pdrops_]"
    set meanq [expr $meanq + $barrivals_-$bdepartures_-$bdrops_]
    incr count
    if { $count == 10 } {
	    puts -nonewline $file " [expr $meanq / $count]" 
	    set oldmeanq [expr $meanq / $count] 
            set meanq 0
	    set count 0
    }  else {
	 puts -nonewline $file " $oldmeanq"
    }      
    puts $file " $pdrops_"
     
    $ns at [expr $now+$traceSamplingInterval] "myTrace $file"
}

proc myTrace1 {file} {
    global ns N traceSamplingInterval tcp qfile MainLink nbow nclient packetSize enableBumpOnWire tcptype meanq oldmeanq count oldbdepartures

 set now [$ns now]
if {$tcptype == "RTCP"} {      
    
    for {set i 0} {$i < $N} {incr i} {
	set wnd($i) [$tcp($i) set window_]
    }
    
    puts -nonewline $file "$now"    

    for {set i 0} {$i < [expr $N-1] } {incr i} {
	puts -nonewline $file " $wnd($i)"
    }
    puts $file " $wnd([expr $N-1])"
}
    
     
 $ns at [expr $now+$traceSamplingInterval] "myTrace1 $file"
}


proc throughputTrace {file} {
    global ns throughputSamplingInterval qfile flowstats N flowClassifyTime oldbdepartures
    
    set now [$ns now]
    
    $qfile instvar bdepartures_
    
    puts -nonewline $file "$now [expr ($bdepartures_-$oldbdepartures)*8/$throughputSamplingInterval/1000000]"
    set oldbdepartures $bdepartures_
    #set bdepartures_ 0
    if {$now <= $flowClassifyTime} {
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts -nonewline $file " 0"
	}
	puts $file " 0"
    }

    if {$now > $flowClassifyTime} { 
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    $flowstats($i) instvar barrivals_
	    puts -nonewline $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	    set barrivals_ 0
	}
	$flowstats([expr $N-1]) instvar barrivals_
	puts $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	set barrivals_ 0
    }
    $ns at [expr $now+$throughputSamplingInterval] "throughputTrace $file"
}



proc dropTrace {file} {
    global ns dropSamplingInterval qfile flowstats N flowClassifyTime simulationTime totaldrops
    
    set now [$ns now]
    
    puts -nonewline $file "$now"

     if {$now <= $flowClassifyTime} {
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts -nonewline $file " 0"
	}
	puts $file " 0"
    }
  if {$now > $flowClassifyTime} { 
	for {set i 0} {$i < [expr $N-1]} {incr i} {
	    puts "Drop value in round $i"
	    $flowstats($i) instvar pdrops_
	    puts -nonewline $file " $pdrops_"
            set totaldrops($i) $pdrops_; #[expr $totaldrops($i) + $pdrops_]
	    set $pdrops_ 0
	}
	$flowstats([expr $N-1]) instvar pdrops_
	set totaldrops([expr $N-1]) $pdrops_; #[expr $totaldrops([expr $N-1]) + $pdrops_]
	puts $file " $pdrops_"
	set $pdrops_ 0
    }
    $ns at [expr $now+$dropSamplingInterval] "dropTrace $file"
}


$ns color 0 Red
$ns color 1 Orange
$ns color 2 Yellow
$ns color 3 Green
$ns color 4 Blue
$ns color 5 Violet
$ns color 6 Brown
$ns color 7 Black

for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
}

set nqueue [$ns node]
set nclient [$ns node]


$nqueue color red
$nqueue shape box
$nclient color blue

for {set i 0} {$i < $N} {incr i} {
    $ns duplex-link $n($i) $nqueue $inputLineRate [expr $RTT/4] DropTail
    $ns queue-limit $n($i) $nqueue [expr $B * 5]
    $ns duplex-link-op $n($i) $nqueue queuePos 0.25
}


$ns simplex-link $nqueue $nclient $lineRate [expr $RTT/4] $switchAlg
$ns simplex-link $nclient $nqueue $lineRate [expr $RTT/4] $switchAlg
$ns queue-limit $nqueue $nclient $B

######################################Ahmed#########################
if {$qtype == "DropTail/RWNDQ" || $qtype == "DropTail/SICC"} {
	$ns other-queue $nqueue $nclient 

	set  link1   [$ns link $nqueue $nclient]
	set queue1     [$link1 queue]
	$queue1 set-link-capacity [[$link1 set link_] set bandwidth_];
	set  link2   [$ns link  $nclient $nqueue]
	set queue2     [$link2 queue]
	$queue2 set-link-capacity [[$link2 set link_] set bandwidth_];
}

if { $qtype == "XCP" } {
   	set  link1   [$ns link $nqueue $nclient]
	set queue1     [$link1 queue]
	$queue1 set-link-capacity [[$link1 set link_] set bandwidth_];
	set  link2   [$ns link  $nclient $nqueue]
	set queue2     [$link2 queue]
	$queue2 set-link-capacity [[$link2 set link_] set bandwidth_];
}
######################################Ahmed#########################


$ns duplex-link-op $nqueue $nclient color "green"
$ns duplex-link-op $nqueue $nclient queuePos 0.25
set qfile [$ns monitor-queue $nqueue $nclient [open queue.tr w] $traceSamplingInterval]
[$ns link $nqueue $nclient] start-tracing; #queue-sample-timeout;

#setup elephant TCP
for {set i 0} {$i < [expr $neleph]} {incr i} {
    if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
	set tcp($i) [new Agent/TCP/FullTcp/Newreno]
	set sink($i) [new Agent/TCP/FullTcp/Newreno]
	$sink($i) listen
    }
    if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
        set tcp($i) [new Agent/TCP/FullTcp/Sack]
	set sink($i) [new Agent/TCP/FullTcp/Sack]
	$sink($i) listen
    }
    
     if {[string compare $sourceAlg "XCP"] == 0 || [string compare $sourceAlg "DC-TCP-XCP"] == 0} { 
        set tcp($i) [new Agent/TCP/FullTcp/Newreno/XCP]
	set sink($i) [new Agent/TCP/FullTcp/Newreno/XCP]
	$sink($i) listen
    }

    $ns attach-agent $n($i) $tcp($i)
    $ns attach-agent $nclient $sink($i)
    
    $tcp($i) set fid_ [expr $i]
    $sink($i) set fid_ [expr $i]

    $ns connect $tcp($i) $sink($i)       
}

for {set j 1} {$j <= 5} {incr j} {
	for {set i 0} {$i < [expr $nmice]} {incr i} {    
	    if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
		set itcp([expr $i + ($j-1) * $N]) [new Agent/TCP/FullTcp/Newreno]
		set isink([expr $i + ($j-1) * $N]) [new Agent/TCP/FullTcp/Newreno]
		$isink([expr $i +($j-1) * $N]) listen
	    }
	    if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
		set itcp([expr $i + ($j-1) * $N]) [new Agent/TCP/FullTcp/Sack]
		set isink([expr $i +($j-1) * $N]) [new Agent/TCP/FullTcp/Sack]
		$isink([expr $i + ($j-1) * $N]) listen
	    }
	    
	     if {[string compare $sourceAlg "XCP"] == 0 || [string compare $sourceAlg "DC-TCP-XCP"] == 0} { 
		set itcp([expr $i +  ($j-1) * $N]) [new Agent/TCP/FullTcp/Newreno/XCP]
		set isink([expr $i + ($j-1) * $N]) [new Agent/TCP/FullTcp/Newreno/XCP]
		$isink([expr $i +  ($j-1) * $N]) listen
	    }

	    $ns attach-agent $n([expr $i + $neleph]) $itcp([expr $i +  ($j-1) * $N])
	    $ns attach-agent $nclient $isink([expr $i + ($j-1) * $N])
	    
	    $itcp([expr $i +  ($j-1) * $N]) set fid_ [expr $i + $neleph]
	    $isink([expr $i + ($j-1) * $N]) set fid_ [expr $i + $neleph]
    }          
}

for {set i 0} {$i < [expr $neleph]} {incr i} {
    set ftp($i) [new Application/FTP]
    $ftp($i) attach-agent $tcp($i)    
    set totaldrops($i) 0	
}

for {set j 1} {$j <= 5} {incr j} {
	for {set i 0} {$i < [expr $nmice]} {incr i} {
	    set iftp([expr $i + ($j-1) * $N]) [new Application/FTP]
	    $iftp([expr $i +($j-1) * $N]) attach-agent $itcp([expr $i + ($j-1) * $N])    
	    set totaldrops([expr $i + $neleph]) 0	
	}
}

#$ns at $traceSamplingInterval "myTrace $mytracefile"
#$ns at $traceSamplingInterval "myTrace1 $mytracefile1"
$ns at $throughputSamplingInterval "throughputTrace $throughputfile"
$ns at 0.0 "dropTrace $dropfile"

set ru [new RandomVariable/Uniform]
$ru set min_ 0
$ru set max_ 1.0

for {set i 0} {$i < [expr $neleph]} {incr i} {
     $ns at 0.0 "$ftp($i) start"
    $ns at [expr $simulationTime] "$ftp($i) stop"
}
#for {set k [expr $N / 2]} { $k < $N} { incr k } {
#     $ns at 0.0 "$ftp($k) send 1000"
#    #$ns at [expr $simulationTime] "$ftp($k) stop"
#}

set fsize 10000
set repnum 5
set sendtime  0.0
set intersend [expr ($simulationTime - 0.1) / $repnum] ; #$sim(interval)
set round 1

set rtg1          [new RNG]
$rtg1 seed     1  

set n1 [new RandomVariable/Exponential]
$n1 set avg_ 0.000024
$n1 use-rng $rtg1
#$n1 set avg_ [expr  ($qpacketSize * 8 * 2) / ($N * 1100000000)] ; #  $n1 set avg_ 0.0000024

#$n1 set min_ 0

set rtg2          [new RNG]
$rtg2 seed     1  

set n2 [new RandomVariable/Uniform]
$n2 use-rng $rtg2
$n2 set max_ [expr $nmice] 
$n2 set min_ [expr -1 ]



proc send_incast {} {	
    global ns intersend sendtime round iftp fsize N simulationTime qpacketSize itcp isink n1 n2 tcptype nmice neleph
    set now [$ns now]
	for {set i 0} { $i < [expr  $nmice]} { incr i } {
		set indexarr($i) 0
	}
    for {set i 0} { $i < [expr $nmice]} { incr i } {
		#if {$tcptype != "XCP"} {
		#	set [$tcp($i) set window_] 1256
		 #   	set [$sink($i) set window_] 1256
		#}
		#set [$tcp($i) set cwnd_] 1
	    	#set [$sink($i) set cwnd_] 1
		#$ns at [expr $now + ($qpacketSize) * $i / ($N * 1100000000) ] "$ftp($i) send $fsize" 
		$ns connect $itcp([expr $i +  ($round-1) * $N]) $isink([expr $i + ($round-1) * $N]) 

		set stime [$n1 value]
	        $ns at [expr  $stime + $now] "$iftp([expr $i + ($round-1) * $N]) send $fsize" 
		puts "in round $round, server [expr $i + ($round-1) * $N ] send at time [expr  $stime + $now]"
	    
    }
    set sendtime [expr $sendtime + $intersend]
    incr round
    if { $sendtime <= $simulationTime && $round <= 5} {	
	$ns at $sendtime "send_incast"
    }
    
    	
}

set flowmon [$ns makeflowmon Fid]
set MainLink [$ns link $nqueue $nclient]

$ns attach-fmon $MainLink $flowmon

set fcl [$flowmon classifier]

$ns at $flowClassifyTime "classifyFlows"

proc classifyFlows {} {
    global N fcl flowstats
    puts "NOW CLASSIFYING FLOWS"
    for {set i 0} {$i < $N} {incr i} {
	set flowstats($i) [$fcl lookup autp 0 0 $i]
    }
} 


set startPacketCount 0
set stopPacketCount 0

proc startMeasurement {} {
global qfile startPacketCount
$qfile instvar pdepartures_   
set startPacketCount $pdepartures_
}

proc stopMeasurement {} {
global qfile startPacketCount stopPacketCount packetSize startMeasurementTime stopMeasurementTime simulationTime dfile N totaldrops
$qfile instvar pdepartures_ bdepartures_  
set stopPacketCount $pdepartures_
puts "Throughput = [expr ($stopPacketCount-$startPacketCount)/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*$packetSize*8] Mbps"
puts "Throughput = [expr $bdepartures_/(1024.0*1024*($stopMeasurementTime-$startMeasurementTime))*8] Mbps"
for {set i 0} {$i < $N} {incr i} {
	    puts $dfile "$i $totaldrops($i)"
	}
}

$ns at $startMeasurementTime "startMeasurement"
$ns at $stopMeasurementTime "stopMeasurement"
                      
$ns at $simulationTime "finish"
$ns at $sendtime "send_incast"

$ns run
