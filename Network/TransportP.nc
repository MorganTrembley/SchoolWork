#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"

module TransportP {
	provides interface Transport;
	
	uses interface IP;
	uses interface Random;
	uses interface Timer<TMilli> as Retransmit;
	uses interface Timer<TMilli> as Close;
	uses interface Timer<TMilli> as LongClose;
	uses interface Timer<TMilli> as SendData;
	uses interface Timer<TMilli> as listenClose;
	uses interface Timer<TMilli> as writeTimer;
	uses interface Queue<tcpPack> as oldPackets;
	uses interface Chat;
}

implementation {
	bool availPort[256];		//max 8-bit #
	socket_store_t sockets[MAX_NUM_OF_SOCKETS];
	tcpPack tPackage;
	void tcpPackage(tcpPack *Package, uint16_t src, uint16_t srcPort, uint16_t destPort, uint16_t seq, uint8_t ack, uint8_t flags, uint8_t adWindow, uint8_t data, uint8_t *payload);
	
	event void writeTimer.fired() {
		int i = 0, flag = -1, temp = 0;
		bool flip = TRUE;
		socket_t fd;
		uint8_t buffer[256];
		//dbg(TRANSPORT_CHANNEL, "TESTING!!!!!!!!!!\n");
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (sockets[i].lastWritten < sockets[i].transfer && flag == -1 && sockets[i].sendBuff[0] == NULL) {
				fd = i + 1;
				flag = 0;
			} 
		}
		
		if (flag == 0) {
			//dbg(TRANSPORT_CHANNEL, "TESTING!!!!!!!!!! %d\n", fd);
			i = 0;
			
			sockets[fd - 1].lastWritten = temp;
			dbg(TRANSPORT_CHANNEL, "TRANSFER STRING: %.*s\n", i, buffer);
			call Transport.write(fd, buffer, i);
		}
	}
	
	event void listenClose.fired() {
		int i;
		socket_t fd;
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (sockets[i].state == LISTEN) {
				//dbg(TRANSPORT_CHANNEL, "closing %d, %d\n", i + 1, sockets[i + 1].state);
				fd = i + 1;
				call Transport.release(fd);
			} 
		}
	}
	
	event void Retransmit.fired() {
		tcpPack temp;
		socket_t fd;
		int i;
		bool flag = FALSE;
		//dbg(TRANSPORT_CHANNEL, "IN RETRANSMIT!!!\n");
		while (call oldPackets.size() > 0 && !flag) {
			temp = call oldPackets.dequeue();
			for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
				if (temp.destPort == sockets[i].dest.port && !flag) {
					fd = i + 1;
					flag = TRUE;
					
					call Retransmit.startPeriodic(2*sockets[fd - 1].RTT);
				}
			}
			//dbg(TRANSPORT_CHANNEL, "IN RETRANSMIT LOOP!!! PACKET flag: %d ACK: %d TEMPACK: %d\n", temp.flags, sockets[fd - 1].lastAck, temp.seq);
			if (temp.seq <= sockets[fd - 1].lastAck) {
				
			
			} else if (sockets[fd - 1].state == ESTABLISHED) {
				//resend and add to back of queue
				if (temp.flags > 3) {
					dbg(PROJECT3TGEN, "Retransmitting packet: %d, %d\n", temp.flags, sockets[fd - 1].lastAck);
					call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &temp);
					call oldPackets.enqueue(temp);
				}
			} else if (sockets[fd - 1].state == SYN_SENT){//sockets[fd - 1].state == CLOSED || 
				dbg(PROJECT3TGEN, "Reattempting connection\n");
				tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
					sockets[fd - 1].seq, 0, 1, 5, 0, ""); //syn = 1
				dbg(PROJECT3TGEN, "ATTEMPTING CONNECTION\n");
				//dbg(TRANSPORT_CHANNEL, "SENT: %d, %d, %d, %d, %d, %d, %d, %s\n", tPackage.srcPort, tPackage.destPort, 
				//	tPackage.seq, tPackage.ack, tPackage.flags, tPackage.adWindow, tPackage.data, tPackage.payload);
				sockets[fd - 1].RTT = call Retransmit.getNow();
				call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &temp);
				call oldPackets.enqueue(temp);
			} else if (sockets[fd - 1].state == CLOSING) {
				//dbg(TRANSPORT_CHANNEL, "ATTEMPTING CLOSE: %d\n", fd);
				call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &temp);
				call oldPackets.enqueue(temp);
			} else {
			
			}
			
		}
		if (call oldPackets.size() == 0 && sockets[fd - 1].state == ESTABLISHED) {
			//call Transport.close(fd);
			call Retransmit.startPeriodic(10000);
		}
		
	}
	
	event void Close.fired() {
		int i;
		socket_t fd;
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (sockets[i].state == CLOSING) {
				//dbg(TRANSPORT_CHANNEL, "closing %d, %d\n", i + 1, sockets[i + 1].state);
				fd = i + 1;
				call Transport.release(fd);
			} 
		}
	}
	
	event void LongClose.fired() {
		int i;
		socket_t fd;
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (sockets[i].sendBuff[0] == NULL && sockets[i].state == CLOSING) {
				//dbg(TRANSPORT_CHANNEL, "closing %d, %d\n", i + 1, sockets[i + 1].state);
				fd = i + 1;
				call Transport.release(fd);
			} 
		}
	}
	
	event void SendData.fired() {
		int i, j, window;
		socket_t fd;
		uint8_t buff[8];
		dbg(TRANSPORT_CHANNEL, "IN SENDDATA\n");
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (sockets[i].effectiveWindow > 64) {
				window = 3;
			} else if (sockets[i].effectiveWindow > 32 && sockets[i].effectiveWindow <= 64) {
				window = 2;
			} else if (sockets[i].effectiveWindow > 16 && sockets[i].effectiveWindow <= 32) {
				window = 1;
			} else {
				window = 0;
			}
			//dbg(TRANSPORT_CHANNEL, "WINDOW: %d : %d\n", sockets[i].effectiveWindow, fd);
			while (sockets[i].sendBuff[0] != NULL && sockets[i].outstanding < window) {
				fd = i + 1;
				//dbg(TRANSPORT_CHANNEL, "SOCKET BUFFER: %s\n", sockets[fd - 1].sendBuff);
				//dbg(TRANSPORT_CHANNEL, "WINDOW: %d : %d\n", window, sockets[fd - 1].outstanding);
				//dbg(TRANSPORT_CHANNEL, "WINDOW: %d\n", sockets[fd - 1].effectiveWindow);
				memcpy(buff, sockets[fd - 1].sendBuff, 8);
				dbg(PROJECT3TGEN, "truncated payload: %.8s unacked: %d\n", buff, sockets[fd - 1].outstanding);
				if (sockets[fd - 1].bufflen > 7) {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, sockets[fd - 1].lastSent + 1, sockets[fd - 1].lastRcvd, 4, sockets[fd - 1].effectiveWindow, 8, buff);
					sockets[fd - 1].lastSent += 1;
				} else {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, sockets[fd - 1].lastSent + 1, sockets[fd - 1].lastRcvd, 4, sockets[fd - 1].effectiveWindow, sockets[fd - 1].bufflen, buff);
					sockets[fd - 1].lastSent += 1;
				}
				sockets[fd - 1].outstanding += 1;
				call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &tPackage);
				call oldPackets.enqueue(tPackage);
				for (j = 0; j < SOCKET_BUFFER_SIZE; j++) {
					if (j + 8 < SOCKET_BUFFER_SIZE) {
						sockets[fd - 1].sendBuff[j] = sockets[fd - 1].sendBuff[j + 8];
					} else {
						sockets[fd - 1].sendBuff[j] = NULL;
					}
				}
				sockets[fd - 1].bufflen -= 8;
			}
		}
		call Retransmit.startPeriodic(2*sockets[fd - 1].RTT);
	}
	
	command void Transport.removePackets(int srcPort) {
		int i, queueSize = call oldPackets.size();
		tcpPack temp;
		dbg(TRANSPORT_CHANNEL, "IN REMOVE PACKETS\n");
		for (i = 0; i < queueSize; i++) {
			temp = call oldPackets.dequeue();
			if (temp.srcPort == srcPort) {
				
			} else {
				call oldPackets.enqueue(temp);
			}
		}
		call Retransmit.startPeriodic(500);
	}
	
	command void Transport.startServer(uint8_t port) {
		socket_t fd;
   		socket_addr_t addr;
   		dbg(TRANSPORT_CHANNEL, "SET TEST SERVER: %d, %d\n", TOS_NODE_ID, port);
   		addr.port = port;
   		addr.addr = TOS_NODE_ID;
   		fd = call Transport.socket();
   		call Transport.bind(fd, &addr);
   		call Transport.listen(fd);
   		
   		//start accept timer
	}
	
	command socket_t Transport.startClient(uint8_t destination, uint8_t sourcePort, uint8_t destinationPort) {
		uint8_t i;
		socket_t fd = call Transport.socket();
   		socket_addr_t srcAddr;
   		socket_addr_t destAddr;
   		dbg(TRANSPORT_CHANNEL, "SET TEST CLIENT: %d, %d, %d, %d\n", TOS_NODE_ID, destination, sourcePort, destinationPort);
   		srcAddr.port = sourcePort;
   		srcAddr.addr = TOS_NODE_ID;
   		call Transport.bind(fd, &srcAddr);
   		destAddr.port = destinationPort;
   		destAddr.addr = destination;
   		call Transport.connect(fd, &destAddr);
   		//memcpy(sockets[fd - 1].transfer, transfer, sizeof(transfer));
   		//dbg(TRANSPORT_CHANNEL, "sockets test: %s\n", sockets[fd - 1].transfer);
   		call Retransmit.startPeriodic(5000);
   		//start write timer
   		//call writeTimer.startOneShot(5);
   		return fd;
	}
	
	command socket_t Transport.socket() {
		uint8_t i;
		bool flag = 0;
		socket_t temp;
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (!sockets[i].flag && !flag) {
				flag = 1;
				temp = i + 1;
			}
		}
		return temp;
	}
	
	command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {
		int flag = FAIL;
		if (fd == 0 || availPort[addr->port]) {
			
		} else {
			sockets[fd - 1].flag = 1;
			sockets[fd - 1].src.port = addr->port;
			sockets[fd - 1].src.addr = addr->addr;
			sockets[fd - 1].outstanding = 0;
			sockets[fd - 1].lastWritten = 0;
			sockets[fd - 1].effectiveWindow = SOCKET_BUFFER_SIZE;
			availPort[addr->port] = TRUE;
			flag = SUCCESS;
		}
		dbg(TRANSPORT_CHANNEL, "BINDING: %d, %d ON SOCKET: %d\n", sockets[fd - 1].src.addr, sockets[fd - 1].src.port, fd);
		return flag;
	}
	
	command socket_t Transport.accept(socket_t fd) {
		socket_t newFD;
		int i;
		//dbg(TRANSPORT_CHANNEL, "ACCEPTING CONNECTION\n");
		//dbg(TRANSPORT_CHANNEL, "ACCEPT TEST: %d\n", newFD);
		if (sockets[fd - 1].state == LISTEN) {
			newFD = call Transport.socket();
			sockets[newFD - 1].src.addr = sockets[fd - 1].src.addr;
			sockets[newFD - 1].src.port = sockets[fd - 1].src.port;
			sockets[newFD - 1].state = SYN_RCVD;
			sockets[newFD - 1].flag = 1;
			sockets[newFD - 1].effectiveWindow = SOCKET_BUFFER_SIZE;
			//sockets[fd - 1].state = CLOSING;
			sockets[fd - 1].sendBuff[0] = NULL;
		} else {
			for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
				if (sockets[i].state == SYN_RCVD) {
					newFD = i + 1;
				}
			}
		}
		for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
			sockets[newFD - 1].rcvdBuff[i] = NULL;
		}
		//dbg(TRANSPORT_CHANNEL, "RCVD BUFFER TEST: %s | %d\n", sockets[newFD - 1].rcvdBuff, newFD);
		//dbg(TRANSPORT_CHANNEL, "ACCEPT COMPARE new socket: src %d, dest %d, port 1: %d port 2: %d\n", sockets[newFD - 1].src.addr, sockets[newFD - 1].dest.addr, sockets[newFD - 1].src.port, sockets[newFD - 1].dest.port);
		//dbg(TRANSPORT_CHANNEL, "ACCEPT COMPARE client: src %d, dest %d, port 1: %d port 2: %d\n", sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, sockets[fd - 1].src.port, sockets[fd - 1].dest.port);
		dbg(PROJECT3TGEN, "ACCEPTING CONNECTION\n");
		return newFD;
	}
	
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
		int i, j = 0;
		bool flag = FALSE;
		dbg(TRANSPORT_CHANNEL, "IN WRITE %s, %d\n", buff, bufflen);
		if (bufflen <= 128) {
			for (i = 0; i < 128; i++) {
				if (sockets[fd - 1].sendBuff[i] == NULL && j < bufflen) {
					sockets[fd - 1].sendBuff[i] = buff[j];
					j++;
				}
			}
			//memcpy(sockets[fd - 1].sendBuff, buff, bufflen);
		} else {
			for (i = 0; i < 128; i++) {
				if (sockets[fd - 1].sendBuff[i] == NULL && j < bufflen) {
					sockets[fd - 1].sendBuff[i] = buff[j];
					j++;
				}
			}
			for (i = 0; i < bufflen - 128; i++) {
				buff[i] = buff[i + 128];
				buff[i + 128] = NULL;
			}
			call Transport.write(fd, buff, bufflen - j);
		}
		
		
		dbg(TRANSPORT_CHANNEL, "buff: %s\n", sockets[fd - 1].sendBuff);
		sockets[fd - 1].bufflen = bufflen;
		call SendData.startPeriodic(1000);
		
	}
	
	command error_t Transport.receive(pack* package) {
		tcpPack* newPack = (tcpPack*) package;
		socket_t fd, newFD;
		int i, j, k, flag = FAIL;
		dbg(PROJECT3TGEN, "RECEIVED: %d, %d, %d, %d, %d, %d, %d, %.8s\n", newPack->srcPort, newPack->destPort, newPack->seq, newPack->ack, newPack->flags, newPack->adWindow, newPack->data, newPack->payload);
		for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
			if (newPack->flags == 1 && sockets[i].src.port == newPack->destPort && i == 0) {
				fd = i + 1;
				//dbg(TRANSPORT_CHANNEL, "-------FD------- %d, %d, %d\n", fd, newPack->destPort, sockets[i].src.port);
			}
			if (sockets[i].src.port == newPack->destPort && sockets[i].dest.port == newPack->srcPort) {
				fd = i + 1;
			}
		}
		dbg(TRANSPORT_CHANNEL, "-------FD------- %d, %d, %d, %d, %d\n", fd, newPack->destPort, sockets[fd - 1].src.port, newPack->srcPort, sockets[fd - 1].dest.port);
		//dbg(TRANSPORT_CHANNEL, "NEXT EXP: %d\n", sockets[fd - 1].nextExpected);
		//dbg(TRANSPORT_CHANNEL, "LAST ACK: %d\n", sockets[fd - 1].lastAck);
		switch (newPack->flags) {
			case 1 :	//syn to server
				if (sockets[fd - 1].nextExpected == 0) {
					newFD = call Transport.accept(fd);
					sockets[newFD - 1].state = SYN_RCVD;
					sockets[newFD - 1].lastRcvd = newPack->seq;
					sockets[newFD - 1].nextExpected = newPack->seq + 2;
					sockets[newFD - 1].dest.addr = (uint8_t) newPack->payload;
					sockets[newFD - 1].dest.port = newPack->srcPort;
					sockets[newFD - 1].lastFlag = 5;
					sockets[newFD - 1].lastSent = (call Random.rand16())%120;
					sockets[newFD - 1].seq = (call Random.rand16())%120;
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[newFD - 1].src.port, sockets[newFD - 1].dest.port, sockets[newFD - 1].seq, sockets[newFD - 1].lastRcvd + 1, 2, sockets[fd - 1].effectiveWindow, 0, "");
					call IP.build(sockets[newFD - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
					dbg(PROJECT3TGEN, "next exp: %d\n", sockets[fd - 1].nextExpected);
				//dbg(TRANSPORT_CHANNEL, "RECEIVED: %d, %d, %d, %d, %d, %d, %d, %.8s\n", newPack->srcPort, newPack->destPort, newPack->seq, newPack->ack, newPack->flags, newPack->adWindow, newPack->data, newPack->payload);
					dbg(TRANSPORT_CHANNEL, "-------FD------- %d, %d, %d, %d, %d\n", newFD, newPack->destPort, sockets[newFD - 1].src.port, newPack->srcPort, sockets[newFD - 1].dest.port);
					flag = SUCCESS;
				} else {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
						sockets[fd - 1].seq, sockets[fd - 1].lastRcvd, 7, sockets[fd - 1].effectiveWindow, 0, "");
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				}
				break;
			case 2 :	//syn to client
				sockets[fd - 1].lastRcvd = newPack->seq;
				sockets[fd - 1].lastSent = newPack->ack;
				sockets[fd - 1].lastAck = newPack->ack;
				sockets[fd - 1].effectiveWindow = newPack->adWindow;
				sockets[fd - 1].RTT = call Retransmit.getNow() - sockets[fd - 1].RTT;
				dbg(PROJECT3TGEN, "RTT TIMER: %d\n", sockets[fd - 1].RTT);
				tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, sockets[fd - 1].lastSent + 1, sockets[fd - 1].lastRcvd + 1, 3, sockets[fd - 1].effectiveWindow, 0, "");
				call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				sockets[fd - 1].lastSent += 1;;
				call oldPackets.enqueue(tPackage);
				//outstanding++;
				dbg(TRANSPORT_CHANNEL, "CONNECTION ESTABLISHED!\n");	
				sockets[fd - 1].state = ESTABLISHED;
				//call Transport.write(fd, "THIS IS A TEST!!! THIS IS A TEST!!! THIS IS A TEST!!! ", 54);
				//call writeTimer.startOneShot(10);
				//dbg(TRANSPORT_CHANNEL, "RECEIVED: %d, %d, %d, %d, %d, %d, %d, %.8s\n", newPack->srcPort, newPack->destPort, newPack->seq, newPack->ack, newPack->flags, newPack->adWindow, newPack->data, newPack->payload);
				//call Retransmit.startOneShot(1000);
				//dbg(TRANSPORT_CHANNEL, "Socket State: lastAck %d, lastSent %d, lastRcvd %d\n", sockets[fd - 1].lastAck, sockets[fd - 1].lastSent, sockets[fd - 1].lastRcvd);
				break;
			case 3 : 	//establishment
				if (newPack->seq == sockets[fd - 1].nextExpected) {
					sockets[fd - 1].lastRcvd = newPack->seq;
					//sockets[fd - 1].lastAck = newPack->ack;
					sockets[fd - 1].nextExpected = newPack->seq + 1;
					//sockets[fd - 1].lastSent = newPack->ack;
					dbg(TRANSPORT_CHANNEL, "CONNECTION ESTABLISHED!\n");
					dbg(PROJECT3TGEN, "next exp: %d\n", sockets[fd - 1].nextExpected);
					//dbg(TRANSPORT_CHANNEL, "Sending: THIS IS A TEST!!! this is a test!!! THIS IS A TEST!!! \n");	//for testing purposes
					sockets[fd - 1].state = ESTABLISHED;
					//call Chat.setSocket(fd);
					//dbg(TRANSPORT_CHANNEL, "RECEIVED: %d, %d, %d, %d, %d, %d, %d, %.8s\n", newPack->srcPort, newPack->destPort, newPack->seq, newPack->ack, newPack->flags, newPack->adWindow, newPack->data, newPack->payload);
					//dbg(TRANSPORT_CHANNEL, "Socket State: lastAck %d, lastSent %d, lastRcvd %d\n", sockets[fd - 1].lastAck, sockets[fd - 1].lastSent, sockets[fd - 1].lastRcvd);
				} else {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
						sockets[fd - 1].seq, sockets[fd - 1].lastRcvd, 7, sockets[fd - 1].effectiveWindow, 0, "");
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				}
				break;
			case 4 :	//data sending
				//dbg(TRANSPORT_CHANNEL, "payloads : %.8s\n", newPack->payload);
				
				//dbg(TRANSPORT_CHANNEL, "RECEIVED TESTING: %d, %d, %d, %d, %d, %.8s\n", fd, sockets[fd - 1].nextExpected, newPack->seq, newPack->srcPort, newPack->destPort, newPack->payload);
				if (newPack->seq == sockets[fd - 1].nextExpected) {
					//dbg(TRANSPORT_CHANNEL, "RECEIVED: %d, %d, %d, %.8s\n", fd, newPack->srcPort, newPack->destPort, newPack->payload);
					sockets[fd - 1].lastRcvd = newPack->seq;
					sockets[fd - 1].nextExpected = newPack->seq + 1;
					sockets[fd - 1].effectiveWindow -= newPack->data;
					sockets[fd - 1].seq += 1;
					//dbg(TRANSPORT_CHANNEL, "tesing ad window: %d\n", sockets[fd - 1].effectiveWindow);
					j = 0;
					dbg(PROJECT3TGEN, "READING: %.8s\n", newPack->payload);
					for (k = 0; k < SOCKET_BUFFER_SIZE; k++) {
						if (sockets[fd - 1].rcvdBuff[k] == NULL && j < newPack->data) {
							sockets[fd - 1].rcvdBuff[k] = newPack->payload[j];
							j++;
						}
					}
					
					sockets[fd - 1].bufflen += newPack->data;
					dbg(TRANSPORT_CHANNEL, "RCVD BUFFER: %s | %d, %d\n", sockets[fd - 1].rcvdBuff, fd, sockets[fd - 1].bufflen);
					//call Transport.read(fd, sockets[fd - 1].rcvdBuff, sockets[fd - 1].bufflen);
					
					if (newPack->data > 7) {
						sockets[fd - 1].lastFlag = 5;
						tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
							sockets[fd - 1].seq, newPack->seq, 5, sockets[fd - 1].effectiveWindow, 0, "");
						call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
					} else {
						sockets[fd - 1].lastFlag = 6;
						tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
							sockets[fd - 1].seq, newPack->seq, 6, sockets[fd - 1].effectiveWindow, 0, "");
						call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
						call Transport.read(fd, sockets[fd - 1].rcvdBuff, sockets[fd - 1].bufflen);
						//call Close.startOneShot(10000);
					}
					
					//dbg(TRANSPORT_CHANNEL, "next exp: %d\n", sockets[fd - 1].nextExpected);
				} else {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
						sockets[fd - 1].seq, sockets[fd - 1].lastRcvd, sockets[fd - 1].lastFlag, sockets[fd - 1].effectiveWindow, 0, "");
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				}
				
				break;
			case 5 : 	//WIP was retransmit
				//if ack is accurate, from right spot
				//add lask ack to sockets
				//if no timer running for retransmit start one for 2*RTT
				sockets[fd - 1].lastAck = newPack->ack;
				sockets[fd - 1].effectiveWindow = newPack->adWindow;
				//call Retransmit.startOneShot(100);
				break;
			case 6 : 	//close
				//dbg(TRANSPORT_CHANNEL, "ATTEMPTING CLOSE!\n");
				sockets[fd - 1].lastAck = newPack->ack;
				sockets[fd - 1].lastRcvd = newPack->seq;
				//call Transport.close(fd);
				break;
			case 7 : 
				sockets[fd - 1].lastAck = newPack->ack;
				break;
			case 11 :	//fin to server
				
				if (newPack->seq == sockets[fd - 1].nextExpected) {
					call LongClose.startOneShot(5000);
					sockets[fd - 1].state = CLOSING;
					sockets[fd - 1].seq += 1;
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, newPack->ack + 1, newPack->seq, 12, 0, 0, "");
					sockets[fd - 1].nextExpected = newPack->seq + 1;
					sockets[fd - 1].state = CLOSING;
					
					//dbg(TRANSPORT_CHANNEL, "SERVER FIN REC %d\n", fd);
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
					
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, newPack->ack + 1, newPack->seq, 14, 0, 0, "");
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
					call oldPackets.enqueue(tPackage);
					sockets[fd - 1].RTT = 1500;
					call Retransmit.startPeriodic(1500);
					//call Close.startPeriodic(30000);
				} else {
					tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
						sockets[fd - 1].seq, sockets[fd - 1].lastRcvd, 12, sockets[fd - 1].effectiveWindow, 0, "");
					call IP.build(sockets[fd - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				}
				break;
			case 12 : 
				sockets[fd - 1].lastAck = newPack->ack;
				sockets[fd - 1].state = CLOSING;
				
				//call oldPackets.enqueue(tPackage);
				//outstanding++;
				//CLIENT WAITS A LONG TIME TO CLOSE
				break;
			case 13 :
				//officially close server socket
				dbg(TRANSPORT_CHANNEL, "CLOSING SERVER SOCKET\n");
				sockets[fd - 1].nextExpected = newPack->seq + 1;
				dbg(PROJECT3TGEN, "next exp: %d\n", sockets[fd - 1].nextExpected);
				call Close.startOneShot(500);
				break;
			case 14 : 
				call Retransmit.stop();
				call Transport.removePackets(newPack->destPort);
				dbg(TRANSPORT_CHANNEL, "CLOSING CLIENT SOCKET SOON\n");
				call LongClose.startPeriodic(1000);
				tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, newPack->ack + 1, newPack->seq + 1, 13, 0, 0, "");
				call IP.build(sockets[newFD - 1].src.addr, newPack->src, PROTOCOL_TCP, &tPackage);
				break;
			default :
				dbg(TRANSPORT_CHANNEL, "default case - FLAG : %d\n", newPack->flags);
				break;
		}
		//dbg(TRANSPORT_CHANNEL, "LAST ACK: %d\n", sockets[fd - 1].lastAck);
		sockets[fd - 1].outstanding -= 1;
		return flag;
	}
	
	command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
		char temp[bufflen];
		int i;
		dbg(TRANSPORT_CHANNEL, "IN READ: %s | %d, %d\n", buff, fd, bufflen);
		//will end up deleting buffer and resetting effective window when this is called
		for (i = 0; i < bufflen; i++) {
			temp[i] = NULL;
		}
		memcpy(temp, buff, bufflen);
		//dbg(TRANSPORT_CHANNEL, "READING: %d, %d\n",fd, bufflen);
		if (temp[0] == 'h' && sockets[fd - 1].src.port == 41 && TOS_NODE_ID == 1) {
			call Chat.setSocket(fd, temp);
		} else if (sockets[fd - 1].src.port == 41 && TOS_NODE_ID == 1) {
			call Chat.handleMsg(fd ,temp);
		} else {
			call Chat.clientHandleMsg(temp);
		}
		
		
		//dbg(TRANSPORT_CHANNEL, "IN READ: %.*s | %d, %d\n",bufflen, temp, fd, bufflen);
		
		for (i = 0; i < bufflen; i++) {
			sockets[fd - 1].rcvdBuff[i] = NULL;
			sockets[fd - 1].bufflen -= 1;
		}
		
	}
	
	command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
		sockets[fd - 1].dest.port = addr->port;
		sockets[fd - 1].dest.addr = addr->addr;
		sockets[fd - 1].state = SYN_SENT;
		sockets[fd - 1].effectiveWindow = 128;
		sockets[fd - 1].lastSent = (call Random.rand16())%120;
		sockets[fd - 1].seq = (call Random.rand16())%120;
		//attempt to send SYN packet and add SYN to last sent
		tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
			sockets[fd - 1].seq, 0, 1, 128, 0, ""); //syn = 1
		dbg(TRANSPORT_CHANNEL, "ATTEMPTING CONNECTION\n");
		//dbg(TRANSPORT_CHANNEL, "SENT: %d, %d, %d, %d, %d, %d, %d, %s\n", tPackage.srcPort, tPackage.destPort, 
		//	tPackage.seq, tPackage.ack, tPackage.flags, tPackage.adWindow, tPackage.data, tPackage.payload);
		sockets[fd - 1].RTT = call Retransmit.getNow();
		call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &tPackage);
		call oldPackets.enqueue(tPackage);
		sockets[fd - 1].outstanding += 1;
	}
	
	command error_t Transport.close(socket_t fd) {
		int flag = SUCCESS;
		//dbg(TRANSPORT_CHANNEL, "IN CLOSE %d\n", fd);
		//call SendData.stop();
		//call Retransmit.stop();
		tcpPackage(&tPackage, TOS_NODE_ID, sockets[fd - 1].src.port, sockets[fd - 1].dest.port, 
			sockets[fd - 1].lastSent + 1, sockets[fd - 1].lastRcvd, 11, 0, 0, "");
		call IP.build(sockets[fd - 1].src.addr, sockets[fd - 1].dest.addr, PROTOCOL_TCP, &tPackage);
		call oldPackets.enqueue(tPackage);
		sockets[fd - 1].outstanding += 1;
		sockets[fd - 1].state = CLOSING;
		/*
		if (sockets[fd - 1].state != CLOSED && availPort[sockets[fd - 1].src.port]) {
			availPort[sockets[fd - 1].src.port] = FALSE;
			sockets[fd - 1].flag = 0;
			sockets[fd - 1].state = CLOSED;
			sockets[fd - 1].src.addr = 0;
			sockets[fd - 1].src.port = 0;
			sockets[fd - 1].dest.addr = 0;
			sockets[fd - 1].dest.port = 0;
			sockets[fd - 1].lastWritten = 0;
			sockets[fd - 1].lastAck = 0;
			sockets[fd - 1].lastSent = 0;
			sockets[fd - 1].lastRead = 0;
			sockets[fd - 1].lastRcvd = 0;
			sockets[fd - 1].nextExpected = 0;
			for (i = 0; i < 128; i++) {
				sockets[fd - 1].sendBuff[i] = "\0";
				sockets[fd - 1].rcvdBuff[i] = "\0";
			}
			sockets[fd - 1].buffinc = 0;
			sockets[fd - 1].RTT = 0;
			sockets[fd - 1].effectiveWindow = 0;
			dbg(TRANSPORT_CHANNEL, "Socket %d Closed!\n", fd);
			flag = SUCCESS;
		}*/
		return flag;
	}
	
	command error_t Transport.release(socket_t fd) {
		int flag = FAIL, i;
		tcpPack temp;
		if (sockets[fd - 1].state == CLOSING) {// && availPort[sockets[fd - 1].src.port]
			availPort[sockets[fd - 1].src.port] = FALSE;
			sockets[fd - 1].flag = 0;
			sockets[fd - 1].state = CLOSED;
			sockets[fd - 1].src.addr = 0;
			sockets[fd - 1].src.port = 0;
			sockets[fd - 1].dest.addr = 0;
			sockets[fd - 1].dest.port = 0;
			sockets[fd - 1].lastWritten = 0;
			sockets[fd - 1].lastAck = 0;
			sockets[fd - 1].lastSent = 0;
			sockets[fd - 1].lastRead = 0;
			sockets[fd - 1].lastRcvd = 0;
			sockets[fd - 1].nextExpected = 0;
			for (i = 0; i < 128; i++) {
				sockets[fd - 1].sendBuff[i] = "\0";
				sockets[fd - 1].rcvdBuff[i] = "\0";
			}
			while (call oldPackets.size() > 0) {
				temp = call oldPackets.dequeue();
				dbg(PROJECT3TGEN, "Packet Queued: %d, %.8s\n", temp.seq, temp.payload);
			}
			sockets[fd - 1].bufflen = 0;
			sockets[fd - 1].RTT = 0;
			sockets[fd - 1].effectiveWindow = 0;
			dbg(TRANSPORT_CHANNEL, "Socket %d Closed!\n", fd);
			flag = SUCCESS;
			
		}
		return flag;
	}
	
	command error_t Transport.listen(socket_t fd) {
		int flag;
		if (fd == 0) {
			flag = FAIL;
		} else {
			sockets[fd - 1].state = LISTEN;
		}
		dbg(TRANSPORT_CHANNEL, "SOCKET %d LISTENING\n", fd);
		call Close.startOneShot(50000);
		return flag;
	}
	
	void tcpPackage(tcpPack *Package, uint16_t src, uint16_t srcPort, uint16_t destPort, uint16_t seq, uint8_t ack, uint8_t flags, uint8_t adWindow, uint8_t data, uint8_t *payload) {
		Package->src = src;
		Package->srcPort = srcPort;
		Package->destPort = destPort;
		Package->seq = seq;
		Package->ack = ack;
		Package->flags = flags;			
		Package->adWindow = adWindow;
		Package->data = data;
		memcpy(Package->payload, payload, PACKET_MAX_PAYLOAD_SIZE);
	}
}
