/*
 * SICC - SDN-based Incast Congestion Control for Data Centers.
 *
 *  Author: Ahmed Mohamed Abdelmoniem Sayed, <ahmedcs982@gmail.com, github:ahmedcs>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of CRAPL LICENCE avaliable at
 *    http://matt.might.net/articles/crapl/.
 *    http://matt.might.net/articles/crapl/CRAPL-LICENSE.txt
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *  See the CRAPL LICENSE for more details.
 *
 * Please READ carefully the attached README and LICENCE file with this software
 */

"""
SICC switch control network application.
It relies on system function calls to inqure for queue occupancy of OvS
"""


from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import *
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_0
from ryu.lib.mac import haddr_to_bin
from ryu.lib.packet import packet
from ryu.lib.packet import ethernet
from ryu.lib.packet import ether_types
from ryu.lib.packet import tcp
from ryu.lib.packet.tcp import TCPOption
from ryu.lib.packet.tcp import TCPOptionWindowScale
import time
from threading import Timer
from socket import *
from uuid import getnode as get_mac
from ryu.lib.mac import *
import binascii
import struct
import fcntl, socket, struct
import math
from datetime import datetime
import subprocess
import numpy as np
from numpy import *
import cStringIO
import StringIO
from StringIO import StringIO

sampleinterval=0.01
RTT = 500 #500
Capacity = (1*1000*1000*1000)
AMSS = 1000 #1000
Buffer = 85300
BDP=Capacity/8 * RTT *  1/1000000
pipebuffer = math.ceil((BDP + Buffer) / AMSS)
initcwnd = 10

def mac_to_binary(mac):
    addr = ''
    temp = mac.replace(':', '')
    return binascii.unhexlify(temp)

def getHwAddr(ifname):
    	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    	info = fcntl.ioctl(s.fileno(), 0x8927,  struct.pack('256s', ifname[:15]))
    	return ':'.join(['%02x' % ord(char) for char in info[18:24]])


class SimpleSwitch(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_0.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(SimpleSwitch, self).__init__(*args, **kwargs)
        self.mac_to_port = {}
	self.syn_table = {}
	self.fin_table = {}
	self.conn_table = {}
	self.last_conn_table = {}
	self.first_arr_table = {}
	#self.port_conn_table = {}
	self.winscale_table = {}
	self.dstsrc_table = {}
	self.incast_table = {}
	self.timeron = False
	self.count = 0
	self.lastcall = None
	self.totalcount = 0
	self.port_num_to_name = {}
	self.port_backlog = {}
	self.port_avgqueue = {}
	

 
    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch features reply to install table miss flow entries."""
        datapath = ev.msg.datapath_id
        #[self.install_table_miss(datapath, n) for n in [0, 1]]	
	self.getswitchports(datapath)
    
    #def install_table_miss(self, datapath, table_id):
    #    """Create and install table miss flow entries."""
    #    parser = datapath.ofproto_parser
    #    ofproto = datapath.ofproto
    #    empty_match = parser.OFPMatch()
    #    output = parser.OFPActionOutput(ofproto.OFPP_NORMAL)
    #    write = parser.OFPInstructionActions(ofproto.OFPIT_WRITE_ACTIONS,[output])
    #    instructions = [write]
    #    flow_mod = self.create_flow_mod(datapath, 0, 0, 0, table_id, empty_match, instructions)
    #    datapath.send_msg(flow_mod)

    def getswitchports(self, dpid):
	"""get port information from switch having id of dpid."""

	self.port_num_to_name.setdefault(dpid, {})
	p = subprocess.Popen("ssh root@switch ovs-ofctl dump-ports-desc switch | grep '[0-9](' | awk 'BEGIN { FS = \")\" } ; { print $1 }' |  awk 'BEGIN { FS = \"(\" } ; { print $1,$2 }'", shell=True, stdout=subprocess.PIPE)
	str1 = StringIO(p.stdout.read())
	ports = np.genfromtxt(str1, usecols=(0,1), delimiter=' ', dtype=None, unpack=False)	
	for port in ports:	
		#print port[0], port[1]
		self.port_num_to_name[dpid][port[0]] = port[1]	
	print self.port_num_to_name[dpid]
	
	for port in self.port_num_to_name[dpid]:
		portname = self.port_num_to_name[dpid][port]		
		str1= "tc -p -s -d  qdisc show dev %s | grep  backlog | grep -Eo '[0-9]{1,15}b' | sed -e 's/\(b\)*$//g'" % portname
		print str1 
		p = subprocess.Popen("ssh root@switch %s" % str1, shell=True, stdout=subprocess.PIPE)
		string = StringIO(p.stdout.read())
		print port, ":", portname, " backlog=", string.getvalue()

    def sendeth(self, dst, payload="", eth_type="\x7A\x00", interface = "p1p4"):
    	"""Send raw Ethernet packet on interface."""
	dst = mac_to_binary(dst)
	src = mac_to_binary(getHwAddr("p1p4"))
  	assert(len(src) == len(dst) == 6) # 48-bit ethernet addresses
  	assert(len(eth_type) == 2) # 16-bit ethernet type
	
     s = socket.socket(AF_PACKET, SOCK_RAW)

  	# From the docs: "For raw packet
  	# sockets the address is a tuple (ifname, proto [,pkttype [,hatype]])"
  	s.bind((interface, 0))
 	s.send(dst + src + eth_type + payload)
	#print 'sending ' + dst + src + eth_type + payload
	s.close()


    def check_connections(self):
	#print "From check_connections time is ", datetime.now()
	global pipebuffer, RTT
	#incast = False
	total_arr = {}
	total_last ={}
	total_first ={}
	#####################################getting queue occupancy and connection setup info##############################
	if self.conn_table is not None:
	   for dpid in self.conn_table:
	     total_arr[dpid] = {}
	     total_last[dpid] = {}
	     total_first[dpid] = {}
	     for dst in self.conn_table[dpid].keys():
	      self.conn_table[dpid][dst]=max(0, self.syn_table[dpid][dst] - self.fin_table[dpid][dst])
	      #print self.conn_table[dpid][dst], totalcount
	      if dst in self.mac_to_port[dpid] and self.conn_table[dpid][dst]>0:
            	port = self.mac_to_port[dpid][dst]
		portname = self.port_num_to_name[dpid][port]
		#print port, '->', portname, ' in', self.port_num_to_name
		if portname is not None:
		  str1= "tc -p -s -d  qdisc show dev %s | grep backlog | grep -Eo '[0-9]{1,15}b' | sed -e 's/\(b\)*$//g'" % portname
		  #print str1 
		  p = subprocess.Popen("ssh root@switch %s" % str1, shell=True, stdout=subprocess.PIPE)
		  string = StringIO(p.stdout.read())
		  #print portname, 'backlog =', string.getvalue()
		  backlog=0
		  try:
		 	backlog=int(string.getvalue())
   		  except ValueError:
       			pass
		  self.port_backlog[dpid][port] = backlog
		  self.port_avgqueue[dpid][port] = self.port_avgqueue[dpid][port] * 0.25 +  backlog * 0.75
		  #print port, ':', portname, ' backlog = ', self.port_backlog[dpid][port], 'average= ',  self.port_avgqueue[dpid][port]

		if total_arr[dpid].get(port, None) is None:
		      total_arr[dpid][port]=0
 		if total_last[dpid].get(port, None) is None:
		      total_last[dpid][port]=0
		total_arr[dpid][port] = total_arr[dpid][port] + max(0, self.conn_table[dpid][dst] - self.last_conn_table[dpid][dst])
		total_last[dpid][port] = total_last[dpid][port] + self.last_conn_table[dpid][dst]		
	        self.last_conn_table[dpid][dst] = self.conn_table[dpid][dst]

	#####################################sending incast ON or OFF messages##############################
	if total_arr is not None:
	   for dpid in total_arr:
		for port in total_arr[dpid]:
		  if self.port_avgqueue[dpid][port] is not None:
		    remaining = (Buffer - self.port_avgqueue[dpid][port])
		    extra=total_arr[dpid][port] * AMSS * initcwnd
	            #isincast=(extra>0 and extra > remaining) 
		    isincast=(extra > remaining or self.port_backlog[dpid][port] > Buffer*0.9)
		    print '(', remaining, ',', extra, ',' , total_arr[dpid][port] , ',', isincast , ')'
	            if isincast and self.incast_table[dpid][port] is None:		             
			      self.incast_table[dpid][port] = datetime.now()
			      #incast=True
			      for dst in [mac for (mac, port_) in self.mac_to_port.get(dpid).items() if port_ == port]:
			       if dst in self.conn_table[dpid] and self.conn_table[dpid][dst]>0:
				for src in [mac for (mac, dst_) in self.dstsrc_table.get(dpid).items()  if dst_ == dst]:
				  msg = "Incast is Up, shift by " + `self.winscale_table[dst][src]`
				  #print 'src= ', src, ' dst= ', dst,' msg= ', msg, '\n'		
				  if self.winscale_table[dst][src] >0:
				      eth_type = "%X" % (0x7A00 + self.winscale_table[dst][src]) 
				      self.sendeth(src, msg , binascii.unhexlify(eth_type))
				  else:
				      self.sendeth(src, msg)
	            elif self.incast_table[dpid][port] is not None:
			t= (datetime.now() - self.incast_table[dpid][port]).microseconds 
			if t>= 30 * RTT or (self.port_backlog[dpid][port]<20000 and t >= 8 * RTT):
			      print 'ON time = ', self.incast_table[dpid][port], ',', 'OFF Time = ', datetime.now()
			      self.incast_table[dpid][port] = None					
			      for dst in [mac for (mac, port_) in self.mac_to_port.get(dpid).items() if port_ == port]:
				   if dst in self.conn_table[dpid] and self.conn_table[dpid][dst]>=0:
				   	for src in [mac for (mac, dst_) in self.dstsrc_table.get(dpid).items()  if dst_ == dst]:
						self.sendeth(src, "Incast is Down, stop setting of RWND", "\x7A\x0F") 
	
	Timer(sampleinterval, self.check_connections, ()).start()
		

    def send_desc_stats_request(self, datapath):
	ofp_parser = datapath.ofproto_parser
	req = ofp_parser.OFPDescStatsRequest(datapath)
	datapath.send_msg(req)

    def add_flow(self, datapath, in_port, dst, actions):
        ofproto = datapath.ofproto
	
	match = datapath.ofproto_parser.OFPMatch(
            in_port=in_port, dl_dst=haddr_to_bin(dst))

        mod = datapath.ofproto_parser.OFPFlowMod(
            datapath=datapath, match=match, cookie=0,
            command=ofproto.OFPFC_ADD, idle_timeout=0, hard_timeout=0,
            priority=ofproto.OFP_DEFAULT_PRIORITY,
            flags=ofproto.OFPFF_SEND_FLOW_REM, actions=actions)
        datapath.send_msg(mod)
	
    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def _packet_in_handler(self, ev):
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
	in_port = msg.in_port
	dpid = datapath.id	

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocol(ethernet.ethernet)

        if eth.ethertype == ether_types.ETH_TYPE_LLDP:
            # ignore lldp packet
            return
        dst = eth.dst
        src = eth.src  

	self.syn_table.setdefault(dpid, {})
	self.fin_table.setdefault(dpid, {})
        self.conn_table.setdefault(dpid, {})
        self.last_conn_table.setdefault(dpid, {})
        self.first_arr_table.setdefault(dpid, {})
        self.incast_table.setdefault(dpid, {})
	self.winscale_table.setdefault(src, {})
        self.dstsrc_table.setdefault(dpid, {})
        self.port_backlog.setdefault(dpid, {})
        self.port_avgqueue.setdefault(dpid, {})

	if self.fin_table[dpid].get(dst, None) is None:
		self.fin_table[dpid][dst]=0
	if self.syn_table[dpid].get(dst, None) is None:
		self.syn_table[dpid][dst]=0
	if self.conn_table[dpid].get(dst, None) is None:
		self.conn_table[dpid][dst]=0
	if self.last_conn_table[dpid].get(dst, None) is None:
		self.last_conn_table[dpid][dst]=0
	if self.first_arr_table[dpid].get(dst, None) is None:
		self.first_arr_table[dpid][dst]=None
	if self.incast_table[dpid].get(in_port, None) is None:
		self.incast_table[dpid][in_port]=None
	if self.winscale_table[src].get(dst, None) is None:
		self.winscale_table[src][dst]=0
	if self.dstsrc_table[dpid].get(dst, None) is None:
		self.dstsrc_table[dpid][dst]=0	
	
	self.dstsrc_table[dpid][src]=dst

	tcp1 = pkt.get_protocol(tcp.tcp)
	if tcp1: 
		if (tcp1.bits & 0x0001) == 1 and (tcp1.src_port==80  or tcp1.dst_port==5001):
			#print 'FIN'
			self.fin_table[dpid][dst]=self.fin_table[dpid][dst]+1
			self.totalcount = max(0, self.totalcount - 1)
			self.lastcall = datetime.now()
			#self.conn_table[dpid][dst]=max(0, self.syn_table[dpid][dst] - self.fin_table[dpid][dst])
			if(self.conn_table[dpid][dst]==0):
				self.first_arr_table[dpid][dst]=None
		elif (tcp1.bits == 2 and tcp1.dst_port==5001) or (tcp1.bits == 18 and tcp1.src_port==80):
			#print 'SYN or SYN-ACK'
			self.syn_table[dpid][dst]=self.syn_table[dpid][dst]+1
			self.totalcount = self.totalcount + 1
			self.lastcall = datetime.now()
			if(self.first_arr_table[dpid][dst] is None):
				self.first_arr_table[dpid][dst]=self.lastcall			 		
			#self.conn_table[dpid][dst]=max(0, self.syn_table[dpid][dst] - self.fin_table[dpid][dst])		
			#msg.buffer_id = ofproto.OFP_NO_BUFFER
		if (tcp1.bits & 0x0002) == 2 and tcp1.option is not None:
			#print 'options=', tcp1.option, '\n'
			for opt in tcp1.option:
				if  opt.kind == 3:
					#print 'this is window scale option', opt, 'the shift val = ', opt.shift_cnt, '\n'
					self.winscale_table[src][dst] = opt.shift_cnt
		else:
			self.winscale_table[src][dst] = 0
		if not self.timeron and self.totalcount>0:
			print 'timer started at ', datetime.now()
			Timer(sampleinterval, self.check_connections, ()).start()
			self.timeron=True
		#return


        self.mac_to_port.setdefault(dpid, {})

        #self.logger.info("packet in %s %s %s %s", dpid, src, dst, msg.in_port)

        # learn a mac address to avoid FLOOD next time.
        self.mac_to_port[dpid][src] = msg.in_port
	
	if self.port_num_to_name[dpid].get(msg.in_port, None) is None:
		self.port_num_to_name[dpid][msg.in_port]=None
	if self.port_backlog[dpid].get(msg.in_port, None) is None:
		self.port_backlog[dpid][msg.in_port]=0
	if self.port_avgqueue[dpid].get(msg.in_port, None) is None:
		self.port_avgqueue[dpid][msg.in_port]=0
	
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [datapath.ofproto_parser.OFPActionOutput(out_port)]

        # install a flow to avoid packet_in next time
        if out_port != ofproto.OFPP_FLOOD:
            self.add_flow(datapath, in_port, dst, actions)

        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
        	data = msg.data

        out = datapath.ofproto_parser.OFPPacketOut(
            datapath=datapath, buffer_id=msg.buffer_id, in_port=in_port,
            actions=actions, data=data)
        datapath.send_msg(out)

    @set_ev_cls(ofp_event.EventOFPPortStatus, MAIN_DISPATCHER)
    def _port_status_handler(self, ev):
        msg = ev.msg
        reason = msg.reason
        port_no = msg.desc.port_no

        ofproto = msg.datapath.ofproto
        if reason == ofproto.OFPPR_ADD:
            self.logger.info("port added %s", port_no)
        elif reason == ofproto.OFPPR_DELETE:
            self.logger.info("port deleted %s", port_no)
        elif reason == ofproto.OFPPR_MODIFY:
            self.logger.info("port modified %s", port_no)
        else:
            self.logger.info("Illeagal port state %s %s", port_no, reason)
