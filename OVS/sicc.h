/*
 * SICC - End-host SDN-based Incast Congestion Control Helper Module.
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

#ifndef SICC_H
#define SICC_H 1

#include <linux/types.h>
#include <linux/netfilter.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
#include <linux/netdevice.h>
#include <linux/inet.h>
#include <net/tcp.h>
#include <net/checksum.h>
#include <linux/netfilter_ipv4.h>
#include <linux/string.h>
#include <linux/time.h>
#include <linux/ktime.h>
#include <linux/hrtimer.h>
#include <net/pkt_sched.h>
#include <linux/openvswitch.h>
#include <net/dsfield.h>
#include <net/inet_ecn.h>

#include "datapath.h"
#include "flow.h"
#include "flow_table.h"
#include "flow_netlink.h"
#include "vlan.h"
#include "vport-internal_dev.h"
#include "vport-netdev.h"


/******************************************Ahmed***********************************************/
enum hrtimer_restart timer_callback(struct hrtimer *timer);
void process_packet(struct sk_buff *skb,  struct vport *inp , struct vport *outp);
void add_dev(const struct net_device * dev);
void del_dev(const struct net_device * dev);
void init_sicc(void);
void cleanup_sicc(void);
/******************************************Ahmed***********************************************/

inline bool sicc_enabled(void)
{

}

