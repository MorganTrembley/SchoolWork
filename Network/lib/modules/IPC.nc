configuration IPC {
	provides interface IP;
}

implementation {
	components IPP;
	IP = IPP;
	
	components LinkStateC;
	IPP.LinkState -> LinkStateC;
	
	components LinkLayerC;
	IPP.Link -> LinkLayerC;
	
	components MyPingC;
	IPP.MyPing -> MyPingC;
	
	components TransportC;
	IPP.Transport -> TransportC;
}
