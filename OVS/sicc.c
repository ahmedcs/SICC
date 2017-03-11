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


#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt

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

#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))

#define DEV_MAX 1000

static bool sicc_enable = false;
module_param(sicc_enable, bool, 0644);
MODULE_PARM_DESC(sicc_enable, " sicc_enable enables SICC incast detection mechanism");

static spinlock_t globalLock;
static struct hrtimer my_hrtimer;
static ktime_t ktime;

static unsigned short devcount=0;
static bool fail=false;
static bool reset=false;
static unsigned short count=0;
static bool incast[DEV_MAX];
static short devindex[DEV_MAX];
static unsigned short winscale[DEV_MAX];
static unsigned long int lastincast[DEV_MAX];

inline bool sicc_enabled(void)
{
    return sicc_enable;
}

void process_packet(struct sk_buff *skb,  struct vport *inp , struct vport *outp)
{
    const struct net_device *in=netdev_vport_priv(inp)->dev;
    const struct net_device *out=netdev_vport_priv(outp)->dev;
    bool incast_pkt;
  
    u16 new_win, old_win;
    int i=-1,j=-1,k=0;
    
    if(!sicc_enable && !reset)
    {
		init_sicc();
		reset=true;
    }	

    if (skb && in && out && !fail && sicc_enable)
    {
		while(k < devcount)
		{
			if(devindex[k] == in->ifindex)
				 i=k;
			if(devindex[k] == out->ifindex)
				 j=k;
			k++;
		}
		if(i==-1 || j==-1)
		{
			   if(i==-1)
			   {
					add_dev(in);
					i=0;
			   }
			   if(j==-1)
			   {
					add_dev(out);
					j=0;
			   }
		}
		if(jiffies_to_msecs(jiffies - lastincast[j]) >= 1000)
		{
			incast[j]=false;
			lastincast[j]=0;
		}
			struct ethhdr *mh = eth_hdr(skb);  
		if(ntohs(mh->h_proto)>=31232 && ntohs(mh->h_proto)<=31246)
		{
			if(!incast[j])
				lastincast[j]=jiffies;
			incast[j] = true;
			winscale[j] = ntohs(mh->h_proto) - 31232;
			printk(KERN_INFO "REcieved Incast ON message: [%i:%s->%i:%s] [%pM->%pM] and winscale= %d\n", devindex[i], (const char*)in->name, devindex[j], (const char*)out->name, mh->h_source, mh->h_dest, winscale[j]);
			kfree_skb(skb);
					return;
		}
		else if(ntohs(mh->h_proto) == 31247)
		{
			incast[j] = false;
			lastincast[j]=0;
			printk(KERN_INFO "REcieved Incast OFF message setting for device: [%i:%s->%i:%s]\n", devindex[i], (const char*) in->name, devindex[j], (const char*)out->name);
			kfree_skb(skb);
					return;
		}
		else{
			struct iphdr * ip_header = ip_hdr(skb); //(struct iphdr *)skb_network_header(skb);

			if (ip_header && ip_header->protocol == IPPROTO_TCP)
			{
				struct tcphdr * tcp_header = tcp_hdr(skb); 
				if(tcp_header->ack)
				{ 
						if(incast[j] == true)
						{
						if(winscale[j]>0)
							new_win = htons(1500>>winscale[j]);
						else
									new_win = htons(1500); //htons(TCP_BASE_MSS);
							 __be16 old_win = tcp_header->window;
							 tcp_header->window = new_win;
							 csum_replace2(&tcp_header->check, old_win, new_win);
						 	//printk(KERN_INFO "new window: [%i:%s->%i:%s] [%pI4h:%d->%pI4h:%d] %d->%d winscale:%d\n", devindex[i], (const char*) in->name,devindex[j], (const char*)out->name, &ip_header->saddr, ntohs(tcp_header->source), &ip_header->daddr, ntohs(tcp_header->dest), ntohs(old_win), ntohs(tcp_header->window), winscale[j]);
						}
				
				 }
			}
		}
    }
    if(skb && outp)
	  ovs_vport_send(outp, skb);
}

void add_dev(const struct net_device * dev)
{
    if(dev==NULL || devcount+1>DEV_MAX)
    {
        fail=true;
        printk(KERN_INFO "OpenVswitch : Fatal Error Exceed Allowed number of Devices : %d \n", devcount);
        return;
    }
    devindex[devcount] = dev->ifindex;
    incast[devcount]=false;
    winscale[devcount]=0;
    lastincast[devcount]=0;

    printk(KERN_INFO "OpenVswitch ADD: [%i:%s]\n", devindex[devcount], (const char*)dev->name);
    devcount++;
    printk(KERN_INFO "OpenVswitch ADD: total number of detected devices : %d \n", devcount);

}

void del_dev(const struct net_device * dev)
{
    int i=-1;
    if(dev==NULL || devcount<=0)
        return;
    if(i<0)
    {
        int i=0;
        while(i<devcount && devindex[i]!=dev->ifindex)
        {
            i++;
        }
    }
    if(i<devcount)
    {
        printk(KERN_INFO "OpenVswitch DEL: [%d:%s] \n", devindex[i], (const char*)dev->name);
        int j=i;
        while(j<devcount && devindex[j+1]!=-1)
        {
            devindex[j] = devindex[j+1];
            incast[j]=incast[j+1];
	    	winscale[j]=winscale[j+1];
	    	lastincast[j]=lastincast[j+1];
            j++;
        }

        devcount--;
        printk(KERN_INFO "OpenVswitch DEL: total number of detected devices : %d \n", devcount);
    }
}

void init_sicc(void)
{
    devcount=0;
    fail=false;

    int i=0;
    while( i < DEV_MAX)
    {

        devindex[i]=-1; 
        incast[devcount]=false;
        winscale[i]=0;
		lastincast[i]=0;
        i++;

    }
    printk(KERN_INFO "OpenVswitch Init SICC: sicc_enable: %d \n" sicc_enable);

    return;
}

void cleanup_sicc(void)
{
    printk(KERN_INFO "OpenVswitch Stop SICC \n");
}


