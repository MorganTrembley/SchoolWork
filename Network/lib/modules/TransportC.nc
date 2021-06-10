configuration TransportC {
	provides interface Transport;
}

implementation {
	components TransportP;
	Transport = TransportP;
	
	components IPC;
	TransportP.IP -> IPC;
	
	components RandomC;
	TransportP.Random -> RandomC;
	
	components new TimerMilliC() as Retransmit;
	TransportP.Retransmit -> Retransmit;
	
	components new TimerMilliC() as Close;
	TransportP.Close -> Close;
	
	components new TimerMilliC() as LongClose;
	TransportP.LongClose -> LongClose;
	
	components new TimerMilliC() as SendData;
	TransportP.SendData -> SendData;
	
	components new TimerMilliC() as listenClose;
	TransportP.listenClose -> listenClose;
	
	components new TimerMilliC() as writeTimer;
	TransportP.writeTimer -> writeTimer;
	
	components new QueueC(tcpPack, 64) as oldPackets;
	TransportP.oldPackets -> oldPackets;
	
	components ChatC;
	TransportP.Chat -> ChatC;
}
