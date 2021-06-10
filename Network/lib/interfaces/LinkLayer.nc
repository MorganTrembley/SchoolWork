interface LinkLayer {
	command void test();
	command void repack(uint16_t src, uint16_t dest, pack payload);
	command void unpackND(pack* msg);
	command void unpackF(pack* msg);
}
