#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module IPP {
	provides interface IP;
	
	uses interface LinkState;
	uses interface LinkLayer as Link;
	uses interface MyPing;
	uses interface Transport;
}

implementation {
	pack IPPkt;
	void packIt(pack *IPPacket, uint16_t src, uint16_t dest, uint8_t protocol, uint8_t *payload);
	
	command void IP.build(uint16_t src, uint16_t dest, uint8_t protocol, uint8_t *payload) {
			packIt(&IPPkt, src, dest, protocol, payload);
			//dbg(TRANSPORT_CHANNEL, "packed: %d\n", IPPkt.dest);
			call IP.sendPkt(&IPPkt);
	}
	
	
	command void IP.sendPkt(pack* payload) {
		packIt(&IPPkt, payload->src, payload->dest, payload->protocol, payload->payload);
		//dbg(TRANSPORT_CHANNEL, "%d\n", IPPkt.dest);
		if (IPPkt.dest == TOS_NODE_ID) {
			call IP.sortReply(payload);
		} else if (call LinkState.getNext(payload->dest) == 0) {
			dbg(ROUTING_CHANNEL, "DESTINATION UNREACHABLE!\n");
		} else {
			//dbg(TRANSPORT_CHANNEL, "sending from %d to %d\n", TOS_NODE_ID, call LinkState.getNext(payload->dest));
			call Link.repack(TOS_NODE_ID, call LinkState.getNext(payload->dest), IPPkt);
		}
	}
	
	command void IP.sortReply(pack* Packet) {
		switch (Packet->protocol) {
			case PROTOCOL_MY_PING :
				call MyPing.complete(Packet->payload);
				break;
			case PROTOCOL_TCP :
				//dbg(TRANSPORT_CHANNEL, "reply test\n");
				call Transport.receive(Packet->payload);
				break;
			default :
				dbg(ROUTING_CHANNEL, "IP: INTERFACE NOT IMPLEMENTED\n");
				break;
			}
	}
	
	void packIt(pack *IPPacket, uint16_t src, uint16_t dest, uint8_t protocol, uint8_t *payload) {
		IPPacket->src = src;
		IPPacket->dest = dest;		
		IPPacket->protocol = protocol;
		memcpy(IPPacket->payload, payload, PACKET_MAX_PAYLOAD_SIZE);
	}
}
