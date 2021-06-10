configuration ChatC {
	provides interface Chat;
}

implementation {
	components ChatP;
	Chat = ChatP;
	
	components TransportC;
	ChatP.Transport -> TransportC;
}
