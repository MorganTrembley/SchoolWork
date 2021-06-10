interface Flooding {
	command void Flood(uint16_t dest, uint8_t protocol, uint8_t *payload);
	command void control(pack* Fpacket);
	command void sendPack(pack Fpkg, uint16_t Fsrc);
}
