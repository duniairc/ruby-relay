####
## ruby-relay
## relay plugin
##
## Copyright (c) 2013 Andrew Northall
##
## MIT License
## See LICENSE file for details.
####

class RelayPlugin
  include Cinch::Plugin
  
  listen_to :message, method: :relay
  listen_to :part, method: :relay_part
  listen_to :quit, method: :relay_quit
  listen_to :kick, method: :relay_kick
  listen_to :join, method: :relay_join
  listen_to :nick, method: :relay_nick
  listen_to :mode, method: :relay_mode
  
  
  def relay(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    if m.action?
      message = "#{network} * #{m.user.nick} #{m.action_message}"
    else
      message = "#{network} <#{m.user.nick}> #{m.message}"
    end
    send_relay(message)
  end
  
  def relay_mode(m)
    return if m.params.nil?
    return if @bot.irc.network.name.nil? #not connected yet
    netname = @bot.irc.network.name.to_s
    return unless m.params[0] == $config["servers"][netname]["channel"]
    m.user.refresh
    if m.user.nil?
      user = m.raw.split(":")[1].split[0]
    else
      user = "#{m.user.nick} (#{m.user.mask.to_s.split("!")[1]})"
    end
    network = Format(:bold, "[#{@bot.irc.network.name}]")
    message = "#{network} - #{user} set mode #{m.params[1..-1].join(" ")} on #{m.params[0]}."
    send_relay(message)
  end
  
  def relay_nick(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.user.channels.include? $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    message = "#{network} - #{m.user.last_nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
              "is now known as #{m.user.nick}."
    send_relay(message)
  end
  
  def relay_part(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    m.user.refresh
    message = "#{network} - #{m.user.nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
		          "has parted #{m.channel.name} (#{m.message})"
    send_relay(message)
  end
  
  def relay_quit(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    network = Format(:bold, "[#{netname}]")
    message = "#{network} - #{m.user.nick} has quit (#{m.message})"
    send_relay(message)
  end
    
  def relay_kick(m)
    netname = @bot.irc.network.name.to_s
    return unless m.channel == $config["servers"][netname]["channel"]
    if m.params[1].downcase == @bot.nick.downcase
      Channel($config["servers"][netname]["channel"]).join
      return
    end
    network = Format(:bold, "[#{netname}]")
    message = "#{network} - #{m.params[1]} (#{User(m.params[1]).mask.to_s.split("!")[1]}) " + \
		          "has been kicked from #{m.channel.name} by #{m.user.nick} (#{m.message})"
    send_relay(message)
  end
  
  def relay_join(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    m.user.refresh
    message = "#{network} - #{m.user.nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
              "has joined #{m.channel.name}"
    send_relay(message)
  end
  
  def send_relay(m)
    $bots.each do |network, bot|
      unless bot.irc.network == @bot.irc.network
        begin
          bot.irc.send("PRIVMSG #{$config["servers"][network]["channel"]}" + \
                       " :#{m}")
        rescue => e
          # pass
        end
      end
    end
  end
end
