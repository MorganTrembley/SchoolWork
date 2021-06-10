interface Chat {

	command void startChatServer(uint8_t port);
	command void startChatClient(uint8_t destination, uint8_t sourcePort, uint8_t destinationPort, uint8_t *transfer);
	command void setSocket(socket_t fd, uint8_t *temp);
	command void handleMsg(socket_t fd, uint8_t *temp);
	command void clientHandleMsg(uint8_t *msg);
}
