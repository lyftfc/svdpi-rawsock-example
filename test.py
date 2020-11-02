#!/usr/bin/python

from mininet.net import Mininet
from mininet.node import Controller, OVSSwitch, Switch, Node
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.util import errFail, waitListening

class SimuSwitch(Switch):
    binary = "make run_wave"

    def __init__(self, name, logFile="/dev/null", inNamespace=True, parameters=[], **params):
        Switch.__init__( self, name, inNamespace=inNamespace, **params )
        self._logFile = logFile
        self._params = parameters

    def start(self, controllers):
        cmd = [self.binary] + self._params
        self.cmd(" ".join(cmd) + " &> " + self._logFile + " &")

    def stop(self):
        self.cmd('pkill xsim')
        pass

def createTopo():

    net = Mininet( controller=Controller, switch=SimuSwitch, link=TCLink )
    # net = Mininet()

    info( '*** Adding controller\n' )
    net.addController('c0')

    info( '*** Adding hosts\n' )
    h1 = net.addHost('h1')
    h2 = net.addHost('h2')
    h3 = net.addHost('h3')

    info( '*** Adding switch\n' )
    s1 = net.addSwitch('s1', logFile="./xsim-mn-out.log")

    info( '*** Creating links\n' )
    l1 = net.addLink(h1, s1)
    l2 = net.addLink(h2, s1)
    l3 = net.addLink(h3, s1)

    return net

if __name__ == '__main__':

    setLogLevel( 'info' )
    nw = createTopo()

    info( '*** Starting network\n' )
    nw.start()

    info( '*** Disable checksum offloading\n')
    for h in nw.hosts:
        h.cmd('/usr/sbin/ethtool -K ' + h.name + '-eth0 rx off tx off sg off')

    info( '*** Starting sshd on hosts\n' )
    for h in nw.hosts:
        h.cmd('/usr/sbin/sshd -D -o UseDNS=no -u0 &')

    CLI( nw )

    info( '*** Stopping network' )
    for h in nw.hosts:
        h.cmd('kill %/usr/sbin/sshd')
    nw.stop()
