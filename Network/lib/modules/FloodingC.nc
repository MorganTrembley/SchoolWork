configuration FloodingC {
	provides interface Flooding;
}

implementation {
	components FloodingP;
	Flooding = FloodingP;
	
	components LinkLayerC;
	FloodingP.Link -> LinkLayerC;
	
	components NeighborDiscoveryC;
	FloodingP.Neighbors -> NeighborDiscoveryC;
	
	components LinkStateC;
	FloodingP.LinkState -> LinkStateC;
}
