
7090-SW-SPBRE_O1I01# show int Xg 1/4/1

Xg1/4/1 up, line protocol is up (connected)
Bridge Port Type: Provider Network Port

Hardware Address is 70:dd:a1:6e:b8:48   
MTU  9600 bytes, No-Negotiation
Alias Name LT:CONN_TO_SW-SPSPO_JU11_1/4/1

Operational value: Full duplex, 10 Gbps
Configured value: Full duplex, 10 Gbps
HOL Block Prevention enabled.
Operational input flow-control is off, output flow-control is off
Configured input flow-control is off, output flow-control is off

SD Set Window value: 100000 frames
SD Set Threshold value: 1 frames
SF Set Window value: 1000 frames
SF Set Threshold value: 1 frames

Link flap monitor status : diabled
Link flap monitor window : 60
Link flap number : 3
Link flap clear window : 120

Link Up/Down Trap is enabled 
LOS Trap is enabled 
LOSYNC Trap is enabled 
TRDI-E Trap is enabled 
Auto-Neg Failure Trap is enabled 
SF Trap is enabled 
SD Trap is enabled 
Link-flap Trap is enabled

Discontinuity Time : 0

BwpLayer : L2

Reception Counters
   HCInOctets                : 314968348215
   HCInUcast                 : 592037462
   HCInMcast                 : 20571234
   HCInBcast                 : 6251260
   Discarded Packets         : 619259121
   Error Packets             : 0

Transmission Counters
   HCOutOctets               : 361319185
   HCOutUcast                : 1755406
   HCOutMcast                : 82493
   HCOutBcast                : 25475
   Discarded Packets         : 146195725
   Error Packets             : 0

7090-SW-SPBRE_O1I01# show int Xg 1/4/1 t

          TX          RX          Supply      Temp        Bias        
          Power       Power       Voltage                 Current     
Port      (dBm)       (dBm)       (V)         (C)         (mA)        
-----     ---------   ---------   ---------   ---------   ---------   
Xg1/4/1   -2.10       -5.94       3.318       28          31600       

7090-SW-SPBRE_O1I01# show int Xg 1/4/1 d

Interface    Admin    Oper             ALS Admin        Laser         Link Flap 
    
             Status   Status           State            Status        Status    
    
---------    ------   ------           ---------        --------      --------  
    
Xg1/4/1      up       up               disabled         disabled      not set   
    

7090-SW-SPBRE_O1I01#




SW-SPBRE_O1I01 
sh int Xg 1/4/1 d 
Name LT:CONN_TO_SW-SPSPO_JU11_1/4/1 
sh int Xg 1/4/1 t 


CAIXA 2 DE SPBRE_POP
SW-SPBRE_O1I01-02 
sh int Xg 1/2/1 
sh int Xg 1/2/1 d 
sh int Xg 1/2/1 t 


CAIXA TERREMARK 
SW-SPBRE_O1I01-03 
sh int Xg 1/2/1 
sh int Xg 1/2/1 t 
sh int Xg 1/2/1 d 
Alias Name LT:CONN_TO_SW-SPSPO_JU11_1/2/1 

sh int Xg 1/4/1 
Name LT:CONN_TO_SW-SPBRE_O1I01_1/2/1 


