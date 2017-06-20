#include "sicc.h"
#include "random.h"
#include "flags.h"
#include "tcp-full.h"

#define INF 999999999

const double SICC::queue_wieght_=0.75;

static class SICCClass: public TclClass {
public:
	SICCClass() :
		TclClass("Queue/DropTail/SICC") {
	}
	TclObject* create(int, const char* const *) {
		return (new SICC);
	}
} class_droptail_SICC;

SICC::SICC() :
	queue_timer_(NULL), estimation_control_timer_(NULL), syn_rate_timer_(NULL), rtt_timer_(NULL),
			effective_rtt_(0.0) {
	init_vars();
	setupTimers();
}


void SICC::setupTimers() {
	//estimation_control_timer_ = new SICCTimer(this, &SICC::Te_timeout);
	queue_timer_ = new SICCTimer(this, &SICC::Tq_timeout);
    syn_rate_timer_ = new SICCTimer(this, &SICC::Ts_timeout);

	// Scheduling timers randomly so routers are not synchronized
	double T;

	//T= Random::normal(Tq_, 0.2 * Tq_);
	//queue_timer_->sched(T);

	//T = Random::normal(0.001, 0.2 * 0.001);
	//estimation_control_timer_->sched(T);

	T = Random::normal(Ts_, 0.2 * Ts_);
	syn_rate_timer_->sched(T);
}

void SICC::setBW(double bw) {
	if (bw > 0)
		link_capacity_bps_ = bw;
}

void SICC::setChannel(Tcl_Channel queue_trace_file) {
	queue_trace_file_ = queue_trace_file;
}

Packet* SICC::deque() {
	Packet* p = DropTail::deque();
	do_before_packet_departure(p);
	
	double now = Scheduler::instance().clock();

	// testing condition: if (incast_ && now - incasttime_ >= 0.6)
	if (incast_ && ( (byteLength() < lowthreshold_) ) ) // && now - incasttime_ >=  minincasttime || now - incasttime_ >= maxincasttime))
	{
		if(debug_>=1)
			printf("SICC: %f Incast stopped q:%f qavg:%f qlowthr:%f incasperiod:%f\n", now,  float(byteLength()), float(queue_avg_), float(lowthreshold_), now - incasttime_);
		incast_=0;
		incasttime_=-1;
	}
	/************************************************End Ahmed*********************************************/


	return (p);
}

void SICC::enque(Packet* pkt) {
	
	double now = Scheduler::instance().clock();
	hdr_cmn *cmnh = hdr_cmn::access(pkt);
	hdr_ip* iph = hdr_ip::access(pkt);
	hdr_tcp *tcph = NULL;
	if (cmnh->ptype() == PT_TCP)
		tcph = hdr_tcp::access(pkt);
	
	double inst_queue = byteLength();
	int pkt_size = int(hdr_cmn::access(pkt)->size());
	
	//Test Condition: if(now > 0.2 && now < 0.201) 
	if(!incastonly_ && !incast_ &&  byteLength()  > highthreshold_) //&& input_traffic_bytes_ > output_traffic_bytes_)
	{
			incast_=1;
			incasttime_=now;
			if(debug_>=1)
				printf("SICC: %f Buffer overflow q:%f qavg:%f highthresh:%f \n", now, float(byteLength()), float(queue_avg_), float(highthreshold_));
	}
	
	//Enqueue if there is room for the non-ACK packets 
	if (!incast_ && byteLength() > ctrllimit )
	{
		if(! ( cmnh->ptype() == PT_ACK || (tcph!=NULL && ( (tcph->flags() & TH_SYN) || (tcph->flags() & TH_FIN) ) ) ) )
		{
			if(tcph && debug_>=2)
				printf("SICC: %f Dropping fid:%d ctrl:%f len:%f NON-ACK of  length %d flags:%d\n", now, iph->flowid(), ctrllimit, byteLength(), pkt_size, (int)tcph->flags());
			else if (debug_>=2)
				printf("SICC: %f Dropping fid:%d ctrl%f len:%f NON-TCP of length %d\n", now, iph->flowid(), ctrllimit, byteLength(), pkt_size);

			DropTail::drop(pkt);			
			return;
		}
	}
	
	do_on_packet_arrival(pkt);
	DropTail::enque(pkt);

}

/*****************************************Ahmed*****************************************/
void SICC::do_on_packet_arrival(Packet* pkt) {
	
	double inst_queue = byteLength();
	if (inst_queue < running_min_queue_bytes_)
		running_min_queue_bytes_ = inst_queue;
    double now = Scheduler::instance().clock();
	int pkt_size = int(hdr_cmn::access(pkt)->size());
	
	hdr_cmn *cmnh = hdr_cmn::access(pkt);
	hdr_ip* iph = hdr_ip::access(pkt);
	hdr_flags* hf = hdr_flags::access(pkt);
	hdr_tcp *tcph = NULL;
	if (cmnh->ptype() == PT_TCP)
		tcph = hdr_tcp::access(pkt);
	
	
	totalenque++;
	qlimb_ = qlim_ * mean_pktsize_;
	input_traffic_bytes_ += pkt_size;
	maxpktsize = max(maxpktsize, pkt_size);
	/*if(cmnh->ptype() == PT_UDP)
		syncount++;*/

	/************************************************Ahmed******************************************/
	//queue_avg_ = qavgupdate(this->byteLength(), queue_avg_, queue_wieght_);
	/*int num = iph->flowid();
	if (num < maxnum && lastrecv[num] >=0) 
	{
		lastrecv[num] = now;
		flow[num]++;
	}*/
	 if (tcph!=NULL && ((tcph->flags() & TH_SYN) || (persist_ && !(tcph->flags() & TH_SYN) && tcph->seqno()==0) ))
	 {
			/*flow[num]++;
			lastrecv[num] = now;*/
			flownum++;
			syncount++;
			if(debug_>= 1)
			{
				printf("SICC: %f SYN syncount:%d fnum:%d fid:%d \n", now, syncount, flownum, iph->flowid());
				if(persist_ && !(tcph->flags() & TH_SYN) && tcph->seqno()==0)
				{
					printf("SICC: %f SEQ=0 Recieved SYN syncount:%d fnum:%d fid:%d \n", now, syncount, flownum, iph->flowid());
				}
			}
	 }
	else if (tcph!=NULL && ( (tcph->flags() & TH_FIN) || (persist_ && !(tcph->flags() & TH_ACK) && hf->cong_action_) ) )
	 {
			/*flow[num]=0;
			lastrecv[num] = -1;*/
			flownum = max(0, flownum-1);
			syncount = max(0, syncount-1);
			if(debug_>= 2)
			{
				if(tcph->flags() & TH_FIN)
					printf("SICC: %f FIN syncount:%d fnum:%d fid:%d\n", now, syncount, flownum, iph->flowid());
				else if(persist_ && !(tcph->flags() & TH_ACK) && hf->cong_action_)
				{
					printf("SICC: %f CWR Recieved FIN syncount:%d fnum:%d fid:%d \n", now, syncount, flownum, iph->flowid());
				}
			}
	 }
	 
}

void SICC::do_before_packet_departure(Packet* p) {
	if (!p)
		return;
	
        double now = Scheduler::instance().clock();

	hdr_cmn *cmnh = hdr_cmn::access(p);
	//hdr_tcp *tcph = NULL; // TCP header
	//if(cmnh->ptype() == PT_ACK || cmnh->ptype() == PT_TCP)
	hdr_tcp *tcph = hdr_tcp::access(p); // TCP header
	if(!tcph)
		return;
	output_traffic_bytes_ += double(cmnh->size());
	++num_cc_packets_in_Te_;
	int id = hdr_ip::access(p)->flowid();
	hdr_flags* hf = hdr_flags::access(p);
	if(otherpq_ != NULL)
	{
		if(debug_>=3)
				printf("SICC: %f Depart flow:%d otherincast:%d ACK:%d TCP:%d TCPACK:%d\n", now,  id, otherpq_->incast_, (cmnh->ptype() == PT_ACK ? 1 : 0), (cmnh->ptype() == PT_TCP ? 1 : 0), (tcph && (tcph->flags() & TH_ACK)));
		if (otherpq_->incast_ &&  otherpq_->flownum >= 1 && (cmnh->ptype() == PT_ACK)) // ||  (tcph && (tcph->flags() & TH_ACK)) ))
		{
			//if(debug_>=2)
				//printf("SICC: Before %f ACK reset flow:%d advwin:%f incast:%d ACK:%d TCP:%d \n", now, id, tcph->advwin(), otherpq_->incast_, (cmnh->ptype() == PT_ACK ? 1 : 0), (cmnh->ptype() == PT_TCP ? 1 : 0));
		    double incomewnd = tcph->advwin();
			if(!divwin_)
				tcph->advwin() = mean_pktsize_; //maxpktsize;
			else
				tcph->advwin() = otherpq_->qlimb_ / otherpq_->flownum;
			
			//------ Mark ECN if we are still above the threshold to force sources to cut their rates
			if(otherpq_->markecn_==1 && otherpq_->byteLength() > otherpq_->highthreshold_)
				hf->ecnecho() = 1;
				
			if(debug_>=2)
				printf("SICC: After %f ACK reset flow:%d advwin:%d incast:%d queue:%f ACK:%d TCP:%d \n", now, id, int(tcph->advwin()), int(otherpq_->incast_), float(otherpq_->queue_avg_), (cmnh->ptype() == PT_ACK ? 1 : 0), (cmnh->ptype() == PT_TCP ? 1 : 0));
		}
	}
	else
	{
	    	printf("SICC: Serious Error otherpq is not set, please fix this");
	        exit(1);
	}
	return;

}

/*****************************************Ahmed*****************************************/
/*
 * Compute the average queue size.
 * Nqueued can be bytes or packets.
 */
inline double SICC::qavgupdate(int nqueued, double ave, double q_w) {
	double new_ave;

	new_ave = ave * (1.0 - q_w) + q_w * nqueued;

	return new_ave;
}

void SICC::Tq_timeout() {
	double inst_queue = byteLength();

	queue_bytes_ = running_min_queue_bytes_;

	oldavg = queue_avg_;

	queue_avg_ = qavgupdate(inst_queue, queue_avg_, queue_wieght_);

	running_min_queue_bytes_ = inst_queue;
	
	queue_timer_->resched(Tq_);
	if (TRACE && (queue_trace_file_ != 0)) {
		trace_var("Tq_", Tq_);
		trace_var("queue_bytes_", queue_bytes_);
	}
}

void SICC::Ts_timeout() {
    double now = Scheduler::instance().clock();
	double inst_queue = byteLength();	
	//oldavg = queue_avg_;
	//queue_avg_ = qavgupdate(inst_queue, queue_avg_, queue_wieght_);
	running_min_queue_bytes_ = inst_queue;
	qlimb_ = qlim_ * mean_pktsize_;
	
	if(debug_>=3)
		printf("%f, in ts_timeout, incastonly:%d, sync:%d, initcwnd:%d, maxp:%d, queueavg:%f\n", now, incastonly_, syncount, initcwnd_, maxpktsize, queue_avg_);
	
	if(!incast_)
	{
		if(incastonly_ && syncount>0 && (syncount * initcwnd_ * maxpktsize) + inst_queue  >= highthreshold_)
		//if(incastonly && syncount>0 && syncount * maxpktsize + queue_avg_  >= qlimb_)
		{
			incast_=1;
			incasttime_=now;
			if(debug_>=1)
				printf("SICC: %f SYN Incast syncount:%d fnum:%d maxp:%d q:%f qavg:%f\n", now, syncount, flownum, maxpktsize, byteLength(), queue_avg_);
			syncount=0;
		}
		/*else if(!incastonly_ && (syncount * initcwnd_ * maxpktsize) + inst_queue  > qlimb_*highthreshold_)
		{
			incast_=1;
			incasttime_=now;
			syncount=0;
			if(debug_>=1)
				printf("SICC: Buffer overflow at time %f maxp:%d qavg:%f qlimb:%d \n", now, maxpktsize, queue_avg_, qlimb_);
		}*/
	}
	/*if (flownum > 0) {
		//int seen = flownum;
		for (int i = 0; i < maxnum_; i++)// && seen); i++)
		{	
			if (lastrecv[i] != -1 &&  now - lastrecv[i] >= 50*Ts_) 
			{	//totalenque -= flow[i];
				flow[i] = 0;
				lastrecv[i] = -1;
				flownum=max(0, flownum-1);
				syncount=max(0, syncount-1);
				//seen--;
				if(debug_==2)
					printf("SICC:  flow %d stopped at time %f\n", i,now);
			}
	
		}
	}*/	
	syncount=0;

	// measure drops, if any
	trace_var("d", drops_);
	drops_ = 0;
	bdrops_ = 0;

	// sample the current queue size
	trace_var("q", length());

	syn_rate_timer_->resched(Ts_);
}

void SICC::drop(Packet* p) {
	drops_++;
	total_drops_++;
	Connector::drop(p);
}

void SICC::setEffectiveRtt(double rtt) {
	effective_rtt_ = rtt;

	rtt_timer_->resched(effective_rtt_);
}

// Estimation & Control Helpers

void SICC::init_vars() {
	qlimb_ = ctrllimit = qlim_ * mean_pktsize_;
	link_capacity_bps_ = 0.0;
	//Tq_ = INITIAL_Te_VALUE;
	Tr_ = 0.1;

	queue_bytes_ = 0.0; // our estimate of the fluid model queue
	queue_avg_ = 0.0;
	old_queue_avg_ = 0.0;

	input_traffic_bytes_ = 0.0;
	output_traffic_bytes_ = 0.0;
	running_min_queue_bytes_ = 0;
	num_cc_packets_in_Te_ = totalinc = totaldec = 0;

	queue_trace_file_ = 0;

	min_queue_ci_ = max_queue_ci_ = length();

	// measuring drops
	drops_ = 0;
	total_drops_ = 0;
	bdrops_ = 0;

	// utilisation;
	total_thruput_ = 0.0;
	
	markecn_=0;
	debug_=0;
	
	/***********************************Ahmed*****************************/
	bind("otherpq_", (TclObject**) &otherpq_);
	bind("flowupdateinterval_", &flowupdateinterval_);
	bind("lowthreshold_", &lowthreshold_);
	bind("highthreshold_", &highthreshold_);	
	bind("maxnum_", &maxnum_);
	bind("incastonly_", &incastonly_);
	bind("debug_", &debug_);
	bind("init_cwnd_", &initcwnd_);
	bind("base_rtt_", &basertt_);
	bind("ack_threshold_", &ackthreshold_);
	bind("incast_", &incast_);
	bind("incasttime_", &incasttime_);
	bind("persist_", &persist_);
	bind("divwin_", &divwin_);
	bind("markecn_", &markecn_);
	
	if(ackthreshold_>=0.5)
		ctrllimit = (ackthreshold_ * qlim_ * mean_pktsize_);
		
	/*if(lowthreshold_ > 0.5)
		lowthreshold_ = 0.2;
	if(highthreshold_< 0.5 || highthreshold_ > 1)
		highthreshold_ = 0.95;*/

	lowthreshold_ = qlimb_ * lowthreshold_;
	highthreshold_ = qlimb_ * highthreshold_;
	
	minincasttime= basertt_;
	maxincasttime= 50 * basertt_;
	Te_  = flowupdateinterval_;
	flownum = 0;
	totalenque = 0;
	currentwnd = oldwnd = INF;
	overflow = false;
	avgpktsize  = maxpktsize = sswndincr = mean_pktsize_;
	wndincr = 0;
	divisor = 10;
	syncount=0;
	Tq_ = Te_ / divisor;
    Ts_ = Te_; //0.0005;
	incasttime_=-1;
    incast_ = 0;
	slowstart = true;
	limitexceed = false;

	/*flow = new int[maxnum];
	lastrecv = new double[maxnum];
	for (int i = 0; i < maxnum; i++) {
		flow[i] = 0;
		lastrecv[i] = -1;
	}*/
	currentfactor = lowthreshold_;
	/**********************************************************************/
	
	printf("SICC-INIT: fu:%f lt:%f ht:%f mn:%d io:%d d:%d icw:%d brtt:%f ath:%f in:%d int:%f mpkt:%d qlim:%d clim:%d persist:%d\n", flowupdateinterval_, lowthreshold_
		   , highthreshold_, maxnum_, incastonly_, debug_,  initcwnd_, basertt_, ackthreshold_, incast_, incasttime_, mean_pktsize_, qlimb_, int(ctrllimit), int(persist_));

}

void SICCTimer::expire(Event *) {
	(*a_.*call_back_)();
}

void SICC::trace_var(char * var_name, double var) {
	char wrk[500];
	double now = Scheduler::instance().clock();

	if (queue_trace_file_) {
		int n;
		sprintf(wrk, "%s %g %g", var_name, now, var);
		n = strlen(wrk);
		wrk[n] = '\n';
		wrk[n + 1] = 0;
		(void) Tcl_Write(queue_trace_file_, wrk, n + 1);
	}
	return;
}

int SICC::command(int argc, const char* const * argv) {
	Tcl& tcl = Tcl::instance();

	if (argc == 2) {
		if (strcmp(argv[1], "queue-read-drops") == 0) {
			if (this) {
				tcl.resultf("%g", totalDrops());
				return (TCL_OK);
			} else {
				tcl.add_errorf("SICC queue is not set\n");
				return TCL_ERROR;
			}
		}

	}

	if (argc == 3) {

		if (strcmp(argv[1], "set-link-capacity") == 0) {
			double link_capacity_bitps = strtod(argv[2], 0);
			if (link_capacity_bitps < 0.0) {
				printf("Error: BW < 0");
				exit(1);
			}
			setBW(link_capacity_bitps / 8.0);
			return TCL_OK;
		} else if (strcmp(argv[1], "drop-target") == 0) {
			drop_ = (NsObject*) TclObject::lookup(argv[2]);
			if (drop_ == 0) {
				tcl.resultf("no object %s", argv[2]);
				return (TCL_ERROR);
			}
			setDropTarget(drop_);
			return (TCL_OK);
		}

		else if (strcmp(argv[1], "attach") == 0) {
			int mode;
			const char* id = argv[2];
			Tcl_Channel queue_trace_file = Tcl_GetChannel(tcl.interp(),
					(char*) id, &mode);
			if (queue_trace_file == 0) {
				tcl.resultf(
						"queue.cc: trace-drops: can't attach %s for writing",
						id);          
				return (TCL_ERROR);
			}
			setChannel(queue_trace_file);
			return (TCL_OK);
		}

		else if (strcmp(argv[1], "queue-sample-everyrtt") == 0) {
			double e_rtt = strtod(argv[2], 0);
			setEffectiveRtt(e_rtt);
			return (TCL_OK);
		}
	}
	return (Queue::command(argc, argv));
}
