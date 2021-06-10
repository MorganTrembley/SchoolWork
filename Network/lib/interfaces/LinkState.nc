interface LinkState {
	command void run();
	command void fill(uint16_t src, uint8_t *payload);
	command void update();
	command void SP();
	command uint16_t getNext(uint16_t dest);
	command void printRouteGraph(uint16_t node);
	command void printRoutingTable(uint16_t node);
}
