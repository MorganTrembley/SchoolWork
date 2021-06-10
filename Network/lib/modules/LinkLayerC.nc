configuration LinkLayerC {
	provides interface LinkLayer;
	
}

implementation {
	components LinkLayerP;
	components NeighborDiscoveryC;
	components FloodingC;
	components new SimpleSendC(50);
	components new AMReceiverC(50) as GeneralReceive;
	LinkLayer = LinkLayerP;
	LinkLayerP.sendPKG -> SimpleSendC;
	LinkLayerP.receivePKG -> GeneralReceive;
	LinkLayerP.ND -> NeighborDiscoveryC;
	LinkLayerP.Flood -> FloodingC;
	
	components IPC;
	LinkLayerP.IP -> IPC;
	
}
