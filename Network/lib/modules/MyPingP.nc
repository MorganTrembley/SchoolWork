#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module MyPingP {
	provides interface MyPing;
	
	uses interface IP;
}

implementation {
	command void MyPing.Ping(uint16_t dest, uint8_t *payload) {
		call IP.build(TOS_NODE_ID, dest, PROTOCOL_MY_PING, payload);
	}
	
	command void MyPing.complete(uint8_t *payload) {
		dbg(TRANSPORT_CHANNEL, "PING COMPLETE: %s\n", payload);
	}
}
