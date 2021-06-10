configuration NeighborDiscoveryC {
	provides interface NeighborDiscovery;
}

implementation {
	components NeighborDiscoveryP;
	components new TimerMilliC() as DiscoveryTimer;
	NeighborDiscovery = NeighborDiscoveryP;
	NeighborDiscoveryP.DiscoveryTimer -> DiscoveryTimer;
	components LinkLayerC;
	NeighborDiscoveryP.Link -> LinkLayerC;
	
	components LinkStateC;
	NeighborDiscoveryP.LinkState -> LinkStateC;
}
