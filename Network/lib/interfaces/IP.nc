interface IP {
	command void build(uint16_t src, uint16_t dest, uint8_t protocol, uint8_t *payload);
	command void sendPkt(pack* payload);
	command void sortReply(pack* Packet);
}
