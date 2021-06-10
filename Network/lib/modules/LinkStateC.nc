configuration LinkStateC {
	provides interface LinkState;
}

implementation {
	components LinkStateP;
	LinkState = LinkStateP;
	
	components RandomC;
	LinkStateP.Random -> RandomC;
	
	components new TimerMilliC() as Delay;
	LinkStateP.Delay -> Delay;
	
	components FloodingC;
	LinkStateP.Flood -> FloodingC;
	
	components NeighborDiscoveryC;
	LinkStateP.ND -> NeighborDiscoveryC;
}
