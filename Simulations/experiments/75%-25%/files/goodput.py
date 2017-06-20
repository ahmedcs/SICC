#!/usr/bin/python
  
import sys
import math
# #############################################################

infile=sys.argv[1]

# #############################################################

N=int(sys.argv[2])

# #########################################################################


infile = open(infile, "r")

# Open input file
cur=1;
avg = []

for count in range(0 , N) :
	avg.append(0)
 
   
infile.seek(0)
total=0  
l = infile.readline()
while l:
      	x = l.split(' ')
	for count in range(0 , N) :        
		avg[count] = avg[count] + float(x[count + 2])
	total = total + 1
	l = infile.readline()
	   
	            
         
	
   

MYFILE = open("avggoodput.tr", "w")
for i in range(0, N) :
      avg[i] = avg[i] / total
      MYFILE.write(str(i + 1) + " " + str(avg[i]) + "\n")
MYFILE.close(); 

   