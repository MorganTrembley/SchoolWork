interface NeighborDiscovery {
	command void start();
	command void response(pack* request, uint16_t source);
	command void newStats(pack* packet);
	command uint8_t getIsNeighbor(int x);
	command void printNeighbors();
}
