#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

typedef struct NodeTable {
	uint16_t lastSeq;
}NodeTable;

module FloodingP {
	provides interface Flooding;
	uses interface LinkLayer as Link;
	uses interface NeighborDiscovery as Neighbors;
	uses interface LinkState;
}

implementation {
	uint16_t Fsequence = 1;
	pack FPackage;
	void package(pack *Package, uint16_t src, uint16_t dest, uint16_t seq, uint8_t TTL, uint8_t protocol, uint8_t *payload);
	struct NodeTable nodeSeq[TABLE_SIZE];
	void initSeq() {
		int i;
		for (i = 0; i < TABLE_SIZE + 1; i++) {	//not the best solution
			nodeSeq[i].lastSeq = 0;
		}
	}
	
	
	//empty for now, easy enough to alter to accept params later if needed
	command void Flooding.Flood(uint16_t dest, uint8_t protocol, uint8_t *payload) {
		initSeq();
		dbg(FLOODING_CHANNEL,"Flooding to %d: Payload: %s\n", dest, payload);
		package(&FPackage, TOS_NODE_ID, dest, Fsequence, 25, protocol, payload);
		call Flooding.sendPack(FPackage, TOS_NODE_ID);
		Fsequence++;
	}
	
	command void Flooding.control(pack* Fpacket) {
		//dbg(FLOODING_CHANNEL, "dbg! %s\n", Fpacket->payload);
		package(&FPackage, Fpacket->src, Fpacket->dest, Fpacket->seq, Fpacket->TTL - 1, Fpacket->protocol, Fpacket->payload);
		dbg(FLOODING_CHANNEL, "Flood Packet Received\n");
		if (FPackage.protocol == PROTOCOL_LINKSTATE) {
			//dbg(ROUTING_CHANNEL, "new LSA: %d\n", FPackage.src);
			call LinkState.fill(Fpacket->src, FPackage.payload);
		}
		if (TOS_NODE_ID == FPackage.dest) {
			if (FPackage.seq > nodeSeq[FPackage.dest].lastSeq) {
				dbg(FLOODING_CHANNEL, "!!!!!!!! Destination Reached: Payload: %s\n", Fpacket->payload);
				nodeSeq[FPackage.dest].lastSeq = FPackage.seq;
			}
		}
		else if (FPackage.TTL > 0) {
			
			call Flooding.sendPack(FPackage, Fpacket->src);
		} else {
			dbg(FLOODING_CHANNEL, "Flood Ended by TTL\n");
		}
	}
	
	command void Flooding.sendPack(pack Fpkg, uint16_t Fsrc) {
		int i, flag = 0;
		dbg(FLOODING_CHANNEL, "Finding Valid Neighbors\n");
		if (Fpkg.seq >= nodeSeq[Fsrc].lastSeq) {	//Fpkg.seq >= nodeSeq[0].lastSeq
			for (i = 0; i < TABLE_SIZE; i++) {
				if (call Neighbors.getIsNeighbor(i) && Fpkg.TTL >= 0 && i != Fsrc) {
					dbg(FLOODING_CHANNEL, "Flooding -> %d\n", i);
					nodeSeq[Fsrc].lastSeq = Fpkg.seq;
					call Link.repack(TOS_NODE_ID, i, Fpkg);
					flag++;
					
				}
			}
			if (!flag) {
				dbg(FLOODING_CHANNEL, "No Valid Neighbors\n");
			}
		} else {
			dbg(FLOODING_CHANNEL, "Repeated Packet!\n");
		}
		
	}
	
	void package(pack *Package, uint16_t src, uint16_t dest, uint16_t seq, uint8_t TTL, uint8_t protocol, uint8_t *payload) {
		Package->src = src;
		Package->dest = dest;
		Package->seq = seq;
		Package->TTL = TTL;			
		Package->protocol = protocol;
		memcpy(Package->payload, payload, PACKET_MAX_PAYLOAD_SIZE);
	}
}
