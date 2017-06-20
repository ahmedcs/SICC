#!/usr/bin/python
  
import sys
import math
from math import *
# #############################################################

infile=sys.argv[1]

# #############################################################
N=int(sys.argv[2])
neleph=(int(floor(float(sys.argv[2])/4)))

print N, neleph

start=0.0 #sys.argv[3]
simtime=5.0 #sys.argv[5]
interval=simtime/5.0 #sys.argv[4]

# #########################################################################


infile = open(infile, "r")

# Open input file
cur=1;
send = []
recv = []
avg = []

for count in range(0 , N) :
	avg.append(0)
	send.append(0)
	recv.append(0)

#while cur <= 5 :  
total1=0
total2=0
   #infile.seek(0)
   
l = infile.readline()
while l:
        x = l.split(' ')
	if float(x[1]) >= start and float(x[1]) < start + cur * interval-0.1 and float(x[1]) <= start + simtime:
		 #print l
		 if x[0] == '+':  
			#print(x)
		       for count in range(neleph , N) :           
			 if send[count-neleph] == 0 and int(x[2]) == count and int(x[7]) == count and int(x[10]) == 0 and int(x[5]) < 80: 
				  #print("pushing send " + str(count) + "\n")
			          #send.insert(count - N, float(x[1]))
				  send[count-neleph] = float(x[1])
				  print("pushing send " + str(count) + "source= " + str(x[2]) + " value=" + str(x[1]) + "total1=" + str(total1)+ "\n")
				  total1 = total1 + 1	   
			    
		 
		 elif x[0]=='r' : #and total2 <= N :
			for count in range(neleph , N ) :
			    if recv[count-neleph]==0 and int(x[3]) == (N + 1) and int(x[7]) == count and int(x[10]) == 8761 and int(x[5]) > 200 :	
				#print("pushing recv " + str(count) + "\n")
				#recv.insert(count - N, float(x[1]))
				recv[count-neleph] = float(x[1])
				print("pushing recv " + str(count) + "dest= " + str(x[3]) + " value=" + str(x[1]) + "total2= " + str(total2)+ "\n")
				total2 = total2 + 1		
 	 

	if (total1 == N-neleph or total1 == N-neleph-1) and float(x[1]) >= start + cur * interval-0.1 and float(x[1]) <= start + simtime:
	   MYFILE = open("fcomp" + str(cur) + ".tr", "w")
	   for i in range(0, N-neleph) :
	      print("total= " + str(total1) + "cur= " + str(cur) + "recv= " + str(recv[i]) + "send =" + str(send[i]) + "\n")
	      if recv[i] > 0:
	      	fcomp=(recv[i] - send[i]) * 1000
	      	MYFILE.write(str(i + neleph) + " " + str(fcomp) + "\n")
	      else:
		MYFILE.write(str(i + neleph) + " 2000" + "\n")
	   MYFILE.close(); 

	   cur = cur + 1
	   for count in range(0 , N-neleph) :
		send[count] = 0
		recv[count] = 0
	
   	   print("Finished Round  " + str(cur) + "\n")
	   total1=0
	l = infile.readline()


in1 = open("fcomp1.tr", "r")
in2 = open("fcomp2.tr", "r")
in3 = open("fcomp3.tr", "r")
in4 = open("fcomp4.tr", "r")
in5 = open("fcomp5.tr", "r")

out1 = open("flowcompavg.tr", "w")
out2 = open("flowcompvar.tr", "w")
out3 = open("flowcompavgstd.tr", "w")

l1 = in1.readline()
l2 = in2.readline()
l3 = in3.readline()
l4 = in4.readline()
l5 = in5.readline()
i=0
while l1 :
        x1 = float(l1.split(' ')[1])
	x2 = float(l2.split(' ')[1])
	x3 = float(l3.split(' ')[1])
	x4 = float(l4.split(' ')[1])
	x5 = float(l5.split(' ')[1])
	avg = (x1 + x2 + x3 + x4 + x5) / 5
	var = ((avg - x1) * (avg - x1) + (avg - x2) * (avg - x2) + (avg - x3) * (avg - x3) + (avg - x4) * (avg - x4) + (avg - x5) * (avg - x5)) / 5
	std = math.sqrt(var)
	out1.write(str(i+ N + 1) + " " + str(avg) + "\n")
	out2.write(str(i+ N + 1) + " " + str(var) + "\n")
	out3.write(str(i+ N + 1) + " " + str(avg) + " " + str(std) + "\n")
	i = i + 1
	l1 = in1.readline()
	l2 = in2.readline()
	l3 = in3.readline()
	l4 = in4.readline()
	l5 = in5.readline()

in1.close()
in2.close()
in3.close()
in4.close()
in5.close()

out1.close()
out2.close()
out3.close()
