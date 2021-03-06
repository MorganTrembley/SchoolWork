from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("some_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    #s.addChannel(s.COMMAND_CHANNEL);
    #s.addChannel(s.GENERAL_CHANNEL);
    #s.addChannel(s.NEIGHBOR_CHANNEL);
    #s.addChannel(s.FLOODING_CHANNEL);
    #s.addChannel(s.ROUTING_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);
    s.addChannel(s.PROJECT3TGEN);
    # After sending a ping, simulate a little to prevent collision.
    #s.runTime(1);
    
    s.runTime(500);
    s.testServerDMP(1,41);
    s.runTime(50);
    s.testClientDMP(2, 1, 5, 41, "hello user 5\r\n");
    s.runTime(1000);
    s.testClientDMP(2, 1, 5, 41, "msg hello\r\n");
    s.runTime(500);
    
    #loop = 3
    #while loop > 1:
    #	msg = raw_input("Enter String: ")
    #	print(msg)
    #	s.testClientDMP(2,1,loop,41,msg);
    #	s.runTime(500);
    #	loop = loop - 1
    
    s.runTime(500);

if __name__ == '__main__':
    main()
