#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

typedef struct users {
	uint8_t name[8];
	socket_t fd;
	uint8_t port;
}users;

module ChatP {
	provides interface Chat;
	
	uses interface Transport;
	
}

implementation {
	struct users usrs[10];
	
	uint8_t* concat(uint8_t *str1, uint8_t *str2) {
		int strlength = strlen((const uint8_t *)str1) + strlen((const uint8_t *)str2), i;
		uint8_t *temp = (uint8_t*) malloc ((strlength + 1)*sizeof(uint8_t));
		dbg(TRANSPORT_CHANNEL, "Concat: %s, %s, %d\n", str1, str2, strlen((const uint8_t *)str1) + strlen((const uint8_t *)str2));
		
		for (i = 0; i <= strlength; i++) {
			if (i < strlen((const uint8_t *)str1)) {
				*(temp + i) = *(str1 + i);
			} else if (i < strlength){
				*(temp + i) = *(str2 + i - strlen((const uint8_t *)str1));
			} else {
				*(temp + i) = '\0';
			}
		}
		
		return temp;
	}
	
	command void Chat.startChatServer(uint8_t port) {
		dbg(TRANSPORT_CHANNEL, "TEST: %d, %d\n", TOS_NODE_ID, port);
		call Transport.startServer(port);
		//call readTimer.startPeriodic(10000);
	}
	
	command void Chat.clientHandleMsg(uint8_t *msg) {
		dbg(TRANSPORT_CHANNEL, "MSG: %s", msg);
	}
	
	command void Chat.setSocket(socket_t fd, uint8_t *temp) {
		uint8_t *cmd, *usr, *msg, *fin;
		uint8_t port;
		uint8_t delim[] = " ", msgDelim[] = "\r\n";
		cmd = strtok(temp, delim);
		usr = strtok(NULL, delim);
		msg = strtok(NULL, msgDelim);
		port = (uint8_t) msg[0];
		fin = concat(cmd,usr);
		dbg(TRANSPORT_CHANNEL, "IN SET SOCKET: %.*s\n", strlen((const uint8_t *)fin), fin);
		memcpy(usrs[port].name, usr, strlen((const uint8_t *)usr));
		dbg(TRANSPORT_CHANNEL, "usrs: %s\n", usrs[port].name);
		usrs[port].fd = fd;
		
		
		//call Transport.write(usrs[port].fd, "hello USERS TEST", 16);
	}
	
	command void Chat.handleMsg(socket_t fd, uint8_t *temp) {
		int i;
		uint8_t *cmd, *usr, *msg, *fin;
		if (*temp == "m") {
			cmd = strtok(temp, " ");
			msg = strtok(NULL, "\r\n");
			fin = concat(usr, msg);
			for (i = 0; i < 10; i++) {
				if (usrs[i].name[0] != NULL) {	//need to concat name of sender
					
					call Transport.write(usrs[i].fd, *fin, strlen((const uint8_t *)fin));
				}
			}
		} else if (*temp == "w") {		//need to concat name of sender
			cmd = strtok(temp, " ");
			usr = strtok(NULL, " ");
			msg = strtok(NULL, "\r\n");
			fin = concat(usr, msg);
			for (i = 0; i < 10; i++) {
				if (!strcmp(usr, usrs[i].name)) {
					
					call Transport.write(usrs[i].fd, *fin, strlen((const uint8_t *)fin));
				}
			}
			
		} else if (*temp == "l") {
			fin = concat(fin, "listUsrRply: ");
			for (i = 0; i < 10; i++) {
				if (usrs[i].name[0] != NULL) {
					fin = concat(fin, usrs[i].name);
					fin = concat(fin, ", ");
				}
			}
			fin = concat(fin, "\r\n");
			call Transport.write(fd, *fin, strlen((const uint8_t *)fin));
		} else {
			
		}
	}
	
	command void Chat.startChatClient(uint8_t destination, uint8_t sourcePort, uint8_t destinationPort, uint8_t *transfer) {
		uint8_t delim[] = " ", i;
		uint8_t msgDelim[] = "\r\n";
		uint8_t *cmd, *usr, *msg;
		//dbg(TRANSPORT_CHANNEL, "split test: %s\n", cmd);
		uint8_t strlength = strlen((const uint8_t *)transfer);
		if (*transfer == 'h') {
			usrs[sourcePort].fd = call Transport.startClient(destination, sourcePort, destinationPort);
			call Transport.write(usrs[sourcePort].fd, transfer, strlength);
		} else {
			dbg(TRANSPORT_CHANNEL, "GEN MSG\n");
			call Transport.write(usrs[sourcePort].fd, transfer, strlength);
			//dbg(TRANSPORT_CHANNEL, "TEST: %s, %s\n", cmd, msg);

		}
		
	}
}
