interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable(uint16_t destination);
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t port);
   event void setTestClient(uint8_t destination, uint8_t sourcePort, uint8_t destinationPort, uint8_t *transfer);
   event void setAppServer();
   event void setAppClient();
}
