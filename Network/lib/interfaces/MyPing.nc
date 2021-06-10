interface MyPing {
	command void Ping(uint16_t dest, uint8_t *payload);
	command void complete(uint8_t *payload);
}
