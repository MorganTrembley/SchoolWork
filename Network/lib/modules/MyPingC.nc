configuration MyPingC {
	provides interface MyPing;
}

implementation {
	components MyPingP;
	MyPing = MyPingP;
	
	components IPC;
	MyPingP.IP -> IPC;
}
