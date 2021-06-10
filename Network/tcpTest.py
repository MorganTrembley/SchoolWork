from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("meyer-heavy.txt");

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
    s.testServerDMP(4,7);
    s.runTime(100);
    s.testServerDMP(4,4);
    s.runTime(100);
    s.testClientDMP(7, 4, 8, 4, 40);
    s.runTime(50);
    s.testClientDMP(7, 4, 3, 7, 40);
    s.runTime(5000);

if __name__ == '__main__':
    main()
