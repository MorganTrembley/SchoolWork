#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define NUM_NODES 19			//edit to reflect number of nodes in topo to make graph pretty
uint8_t updateFlag = 0;
typedef struct nodeGraph {
	uint8_t cost;
}nodeGraph;

typedef struct routing {
	uint16_t next;
	uint8_t cost;
	uint16_t thru;
}routing;

module LinkStateP {
	provides interface LinkState;
	uses interface Flooding as Flood;
	uses interface NeighborDiscovery as ND;
	uses interface Timer<TMilli> as Delay;
	uses interface Random;
}

implementation {
	uint8_t stab;
	struct nodeGraph graph[NUM_NODES][NUM_NODES];
	struct routing confirmed[NUM_NODES + 1];
	struct routing tentative[NUM_NODES + 1];
	
	void initGraph() {
		int i, j;
		for (i = 0; i < NUM_NODES; i++) {
			for (j = 0; j < NUM_NODES; j++) {
				if (i == j && TOS_NODE_ID - 1 == i) {
					graph[i][j].cost = 0;
				} else {
					graph[i][j].cost = 255;
				}
			}
		}
	}
	
	void initRT() {
		int i;
		for (i = 0; i < NUM_NODES + 1; i++) {
			tentative[i].next = TOS_NODE_ID;
			tentative[i].cost = -1;		//max val
			tentative[i].thru = TOS_NODE_ID;
			if (i != TOS_NODE_ID) {
				confirmed[i].next = TOS_NODE_ID;
				confirmed[i].cost = -1;		//max val
				confirmed[i].thru = NULL;
			} else {
				confirmed[i].next = TOS_NODE_ID;
				confirmed[i].cost = 0;		
				confirmed[i].thru = TOS_NODE_ID;
			}
		}
	}
	
	void printRoutingTable(uint8_t node) {
		int i;
		if (TOS_NODE_ID == node) {
			dbg(ROUTING_CHANNEL, "%d's Routing Table:\n", node);
			for (i = 1; i < NUM_NODES + 1; i++) {
				//dbg(ROUTING_CHANNEL, "TENT %d: %d %d %d\n", i, tentative[i].next, tentative[i].cost, tentative[i].thru);
				dbg(ROUTING_CHANNEL, "ROUTE TO %d: Through %d Cost: %d\n", confirmed[i].next, confirmed[i].thru, confirmed[i].cost);
			}
		}
		
	}
	
	command void LinkState.run() {
		//dbg(ROUTING_CHANNEL, "in LS\n");
		//if (TOS_NODE_ID == 12)
		initGraph();
		call Delay.startPeriodic(60000);	//bad solution to waiting for ND to stabalize
		
	}
	
	command void LinkState.update() {
		int temp;
		initRT();
		initGraph();
		updateFlag = 1;
		temp = call Random.rand16();
		temp = temp/250;
				//reinit graph for updates
		
		//dbg(ROUTING_CHANNEL, "update:\n");
		call Delay.startOneShot(5000 + temp); //attempts to avoid timing issues
	}
	
	void printGraph(uint16_t node) {
		int i, j, mod = 0;
		if (TOS_NODE_ID == node && mod%5 == 0) {		//prints graph every 5 iterations through fired -- temporary because I could not implement the python command properly
			dbg(ROUTING_CHANNEL, "GRAPH FOR %d\n", TOS_NODE_ID);
			for (i = 0; i < NUM_NODES; i++) {
				for (j = 0; j < NUM_NODES; j++) {
					if (graph[i][j].cost != 255) {
						printf("%d ", graph[i][j].cost);
					} else {
						printf("X ");
					}
				}
				printf("\n");
			}
		}
		mod++;
	}
	
	event void Delay.fired() {
		int i;
		uint8_t LSA[NUM_NODES] = "";	//init empty table to store neighbor table in for LSA
		stab++;		//gives node time to update and process LSA's before calculating shortest path
		if (updateFlag && stab > 10) {
			stab = 0;
		}
		LSA[0] = TOS_NODE_ID;
		//dbg(ROUTING_CHANNEL, "Stability check: %d %d\n", stab, updateFlag);
		for (i = 1; i < NUM_NODES + 1; i++) {
			if (call ND.getIsNeighbor(i)) {	//can be changed to get cost as well once important
				graph[TOS_NODE_ID - 1][i - 1].cost = 1;
			}
		}
		//cpy noeighbor table into LSA
		for (i = 0; i < NUM_NODES; i++) {
			LSA[i + 1] = graph[TOS_NODE_ID - 1][i].cost;
		}
		
		if (stab == 5) {
			
			call LinkState.SP();
		}
		call Flood.Flood(NULL, PROTOCOL_LINKSTATE, LSA);
		call Delay.startPeriodic(60000);
		
		//printGraph(1);				//!!!PRINT GRAPH - uses printf to look better rather than debug so must be
		//printRoutingTable(4);			//uncommented to show up
	}
	
	command void LinkState.fill(uint16_t src, uint8_t *payload) {
		int i;
		
		for (i = 0; i < NUM_NODES; i++) {
			graph[payload[0] - 1][i].cost = payload[i + 1];
		}
	}
	
	command void LinkState.SP() {
		int i = 1, j = 1, count = 0, nodeID = TOS_NODE_ID, minID = 0;
		//dbg(ROUTING_CHANNEL, "Starting SP!\n");
		initRT();
		//printRoutingTable(4);
		for (j = 1; j < NUM_NODES + 1; j++) {		//not a great way to do this - won't scale - could not find another solution in time
			for (i = 1; i < NUM_NODES + 1; i++) {
				if (graph[nodeID - 1][i - 1].cost > 0 && graph[nodeID - 1][i - 1].cost < 255 && i != TOS_NODE_ID && confirmed[i].cost == 255) {
					tentative[i].next = i;
					minID = tentative[i].next;
					if (nodeID == TOS_NODE_ID) {			//first iter
						tentative[i].cost = graph[nodeID - 1][i - 1].cost;
						tentative[i].thru = i;
					} else if (graph[nodeID - 1][i - 1].cost + confirmed[nodeID].cost < confirmed[i].cost){		//after first iter
						tentative[i].cost = graph[nodeID - 1][i - 1].cost + confirmed[nodeID].cost;	//doesn't work if it has been examined previously
						tentative[i].thru = confirmed[nodeID].thru;
					} else {
					
					}
					//dbg(ROUTING_CHANNEL, " TENTATIVE: %d %d %d\n", tentative[i].next, tentative[i].cost, tentative[i].thru);
					
					//pick ID of lowest cost entry in tentative table for node i
					if (tentative[i].cost < tentative[minID].cost && confirmed[i].cost == 255) {
						minID = i;
					}
					//dbg(ROUTING_CHANNEL, "!!!!!!!!!!!!!!!! %d\n", minID);
					
				}		
			}
			//dbg(ROUTING_CHANNEL, "!!!!!!!!!!!!!!!! min1 %d\n", minID);
			//consults entire tentative list to pick lowest cost ID to commit to confirmed
			for (i = 1; i < NUM_NODES + 1; i++) {
				
				if (tentative[i].cost < tentative[minID].cost && confirmed[i].cost == 255) {
					//dbg(ROUTING_CHANNEL, "ENTER TO CHANGE MIN ID\n");
					minID = i;
				}
			}
			if (tentative[minID].cost < confirmed[minID].cost) {
				confirmed[minID].next = tentative[minID].next;
				confirmed[minID].cost = tentative[minID].cost;
				confirmed[minID].thru = tentative[minID].thru;
				tentative[minID].cost = 254;
			}
			//printRoutingTable(12);
			//dbg(ROUTING_CHANNEL, "!!!!!!!!!!!!!!!!CONFIRMED %d %d %d\n", confirmed[minID].next, confirmed[minID].cost, confirmed[minID].thru);
			count = 0;
			nodeID = minID;
			//dbg(ROUTING_CHANNEL, "!!!!!!!!!!!!!!!! %d %d\n", nodeID, tentative[prev].cost);
		}
		updateFlag = 0;
		printRoutingTable(7);
	}
	
	command void LinkState.printRouteGraph(uint16_t node) {
		printGraph(node);
	}
	
	command void LinkState.printRoutingTable(uint16_t node) {
		printRoutingTable(node);
	}
	
	command uint16_t LinkState.getNext(uint16_t dest) {
		return confirmed[dest].thru;
	}
	
}




































