/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
   uses interface NeighborDiscovery;
   uses interface Flooding;
   uses interface LinkState;
   uses interface MyPing;
   uses interface Transport;
   uses interface Chat;
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call NeighborDiscovery.start();
         call LinkState.run();
         
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}
	
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      //uint8_t *test = "0132";
      //call LinkState.printRouteGraph(TOS_NODE_ID);
      //call LinkState.printRoutingTable(1);
      //dbg(TRANSPORT_CHANNEL, "MY PING EVENT \n");
      dbg(TRANSPORT_CHANNEL, "PrintOut: %s\n", payload);
      //call MyPing.Ping(destination, payload);
      
      //call Flooding.Flood(destination, PROTOCOL_FLOOD, payload);
      //makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      //call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){
   	call NeighborDiscovery.printNeighbors();
   }

   event void CommandHandler.printRouteTable(uint16_t destination){
   	//call LinkState.printRouteGraph(destination);
   	call LinkState.printRoutingTable(destination);
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint8_t port){
   	call Chat.startChatServer(port);
   }

   event void CommandHandler.setTestClient(uint8_t destination, uint8_t sourcePort, uint8_t destinationPort, uint8_t *transfer){
   	call Chat.startChatClient(destination, sourcePort, destinationPort, transfer);
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
