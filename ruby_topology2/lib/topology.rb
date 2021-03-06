# -*- coding: utf-8 -*-
require 'forwardable'
require 'link'
require 'host'
require 'observer'
require 'trema-extensions/port'

#
# Topology information containing the list of known switches, ports,
# and links.
#
class Topology
  include Observable
  extend Forwardable

  attr_reader :ports
  attr_reader :links
  attr_reader :hosts
  def_delegator :@ports, :each_pair, :each_switch
  def_delegator :@links, :each, :each_link
  def_delegator :@hosts, :each, :each_host

  def initialize(view)
    @ports = Hash.new { [].freeze }
    @links = []
    @hosts = []
    add_observer view
  end

  def delete_switch(dpid)
    @ports[dpid].each do | each |
      delete_port dpid, each
    end
    @ports.delete dpid
  end

  def update_port(dpid, port)
    if port.down?
      delete_port dpid, port
    elsif port.up?
      add_port dpid, port
    end
  end

  def add_port(dpid, port)
    @ports[dpid] += [port]
  end

  def delete_port(dpid, port)
    @ports[dpid] -= [port]
    delete_link_by dpid, port
  end

  def add_link_by(dpid, packet_in)
    fail 'Not an LLDP packet!' unless packet_in.lldp?

    link = Link.new(dpid, packet_in)
    unless @links.include?(link)
      @links << link
      @links.sort!
      changed
      notify_observers self
    end
  end

  def add_host_by(dpid, packet_in)
    host = Host.new(dpid, packet_in)
    #unless @hosts.include?(host)
    unless get_host(packet_in.ipv4_saddr.to_s)
      @hosts << host
      @hosts.sort!
      changed
      notify_observers self
    end
  end
  
  # IPアドレスからホストを取得
  def get_host(address)
    result = nil
    @hosts.each do | each |
      if each.ipaddr2.to_s == address
        result = each
        break
      end
    end
    return result
  end
  
  
  private

  def delete_link_by(dpid, port)
    @links.each do | each |
      if each.has?(dpid, port.number)
        changed
        @links -= [each]
      end
    end
    notify_observers self
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:

