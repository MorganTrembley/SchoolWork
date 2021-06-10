from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("test.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    #s.addChannel(s.COMMAND_CHANNEL);
    #s.addChannel(s.GENERAL_CHANNEL);
    #s.addChannel(s.NEIGHBOR_CHANNEL);
    #s.addChannel(s.FLOODING_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);
    #s.addChannel(s.TRANSPORT_CHANNEL);
    # After sending a ping, simulate a little to prevent collision.
    #s.runTime(1);
    #s.ping(3, 12, "Hello, World");
    s.runTime(400);

    #s.routeDMP(6);
    s.ping(8, 9, "Hi!");
    s.runTime(100);
    
    #s.runTime(400);
    
    #s.moteOff(6);
    
    #s.runTime(400);
    
    #s.ping(9, 8, "Hi2!");
    #s.runTime(100);
    
    #s.runTime(400);
    
    #s.moteOn(6);
    
    #s.runTime(400);
    
    #s.ping(9, 4, "Hi3!");
    #s.runTime(250);

if __name__ == '__main__':
    main()
