#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define TABLE_SIZE 20
uint16_t sequence = 0;

typedef struct NeighborStats {
	uint16_t neighborAddr;
	uint16_t requests;
	uint16_t responses;
	uint8_t isNeighbor;
	uint16_t lastSeq;
	uint8_t TTL;
}NeighborStats;

module NeighborDiscoveryP {
	provides interface NeighborDiscovery;
	
	uses interface Timer<TMilli> as DiscoveryTimer;
	uses interface LinkLayer as Link;
	uses interface LinkState;
}

implementation {
	
	pack NDPackage;
	pack NDReturn;
	void package(pack *Package, uint16_t seq, uint8_t TTL, uint8_t protocol, uint8_t *payload);
	
	struct NeighborStats NeighborTable[TABLE_SIZE];
	
	void initTable() {
		int i;
		for (i = 0; i < TABLE_SIZE; i++) {
			NeighborTable[i].neighborAddr = -1;
			NeighborTable[i].requests = 0;
			NeighborTable[i].responses = 0;
			NeighborTable[i].isNeighbor = 0;
			NeighborTable[i].lastSeq = -1;
			NeighborTable[i].TTL = 0;
		}
	}
	//removes old neighbors
	void updateNT() {
		int i, flag = 1;
		for (i = 0; i < TABLE_SIZE; i++) {										//link Quality <= 33%
			if (NeighborTable[i].isNeighbor == 1) {
				NeighborTable[i].TTL--;
				if (NeighborTable[i].TTL <= 0 || NeighborTable[i].responses*3 <= NeighborTable[TOS_NODE_ID].requests) {
					NeighborTable[i].isNeighbor = 0;
					if (flag) {
						call LinkState.update();
					}
				}
			}
		}
		
	}
	
	command void NeighborDiscovery.printNeighbors() {
		int i;
		for (i = 0; i < TABLE_SIZE; i++) {
			if (NeighborTable[i].isNeighbor == 1) {
				dbg(NEIGHBOR_CHANNEL, "%d -> %d\n", TOS_NODE_ID, i);
			}
		}
	}
	
	command void NeighborDiscovery.start() {
		dbg(NEIGHBOR_CHANNEL, "starting Neighbor Discovery\n");
		initTable();
		call DiscoveryTimer.startPeriodic(30000);
		
	}
	
	event void DiscoveryTimer.fired() {
		dbg(NEIGHBOR_CHANNEL, "Firing ND\n");
		package(&NDPackage, sequence, -1, PROTOCOL_PING, "Hello?");
		sequence++;
		call Link.repack(TOS_NODE_ID, AM_BROADCAST_ADDR, NDPackage);
		updateNT();
		call NeighborDiscovery.printNeighbors();
	}
	
	command void NeighborDiscovery.response(pack* request, uint16_t source) {
		if (request->protocol == PROTOCOL_PING) {
			//dbg(NEIGHBOR_CHANNEL, "Responding to neighbor!\n");
			NeighborTable[request->src].requests++;
			package(&NDReturn, request->seq, request->TTL, PROTOCOL_PINGREPLY, "Hello Neighbor!");
			call Link.repack(TOS_NODE_ID, source, NDReturn);
		} else if (request->protocol == PROTOCOL_PINGREPLY) {
			//stat collection
			dbg(NEIGHBOR_CHANNEL, "Collecting Neighbor Stats\n");
			//printf("%d from %d\n", TOS_NODE_ID, request->src);
			NeighborTable[request->src].responses++;
			call NeighborDiscovery.newStats(request);
			
		} else {
			dbg(NEIGHBOR_CHANNEL, "Packet sent to WRONG interface!\n");
		}
	}
	
	command void NeighborDiscovery.newStats(pack* packet) {
		NeighborTable[packet->src].lastSeq = packet->seq;
		NeighborTable[packet->src].neighborAddr = packet->src;
		NeighborTable[packet->src].TTL = 5;
		if (NeighborTable[packet->src].isNeighbor != 1) {
			NeighborTable[packet->src].isNeighbor = 1;
			call LinkState.update();
			updateNT();
		}
	}
	
	void package(pack *Package, uint16_t seq, uint8_t TTL, uint8_t protocol, uint8_t *payload) {
		Package->seq = seq;
		Package->TTL = TTL;			//Q or R for ND -1 for Q, -2 for R
		Package->protocol = protocol;
		memcpy(Package->payload, payload, PACKET_MAX_PAYLOAD_SIZE);
	}
	
	command uint8_t NeighborDiscovery.getIsNeighbor(int x) {
		return NeighborTable[x].isNeighbor;
	}
}
