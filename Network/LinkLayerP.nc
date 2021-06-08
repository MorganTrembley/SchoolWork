#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module LinkLayerP {
	provides interface LinkLayer;
	uses interface SimpleSend as sendPKG;
	uses interface Receive as receivePKG;
	uses interface NeighborDiscovery as ND;
	uses interface Flooding as Flood;
	uses interface IP;
}

implementation {
	void repackage(pack *Package, uint16_t src);
	command void LinkLayer.test() {
		dbg(NEIGHBOR_CHANNEL, "In Link Layer\n");
	}
	
	command void LinkLayer.repack(uint16_t src, uint16_t dest, pack payload) {
		//if (payload.protocol != PROTOCOL_LINKSTATE) {
		repackage(&payload, src);
		//}
		call sendPKG.send(payload, dest);
			//call Sending.startOneShot(temp);
		//dbg(GENERAL_CHANNEL, "Broadcasting Packet\n");
		
	}
	
	event message_t* receivePKG.receive(message_t* msg, void* payload, uint8_t len){
		dbg(GENERAL_CHANNEL, "Packet Received\n");
		if(len==sizeof(pack)) {
			pack* myMsg=(pack*) payload;
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
			switch (myMsg->protocol) {
				case PROTOCOL_PING :
					call LinkLayer.unpackND(myMsg);
					break;
				case PROTOCOL_PINGREPLY :
					call LinkLayer.unpackND(myMsg);
					break;
				case PROTOCOL_FLOOD :
					call LinkLayer.unpackF(myMsg);
					break;
				case PROTOCOL_LINKSTATE :
					call LinkLayer.unpackF(myMsg);
					break;
				case PROTOCOL_MY_PING :
					call IP.sendPkt(myMsg);
					break;
				case PROTOCOL_TCP :
					call IP.sendPkt(myMsg);
					break;
				default :	
				
					break;
			}
			return msg;
		}
		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;
	}
	
	command void LinkLayer.unpackND(pack* msg) {
		call ND.response(msg, msg->src);
	}
	
	command void LinkLayer.unpackF(pack* msg) {
		call Flood.control(msg);
	}
	
	void repackage(pack *Package, uint16_t src) {
		Package->src = src;
	}
}
