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
  listen_to :leaving, method: :relay_part
  listen_to :join, method: :relay_join
  listen_to :nick, method: :relay_nick
  listen_to :mode, method: :relay_mode
  
  
  def relay(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == "#" + $config["servers"][netname]["channel"]
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
    return unless m.params[0] == "#" + $config["servers"][netname]["channel"]
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
    return unless m.user.channels.include? "#" + $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    message = "#{network} - #{m.user.last_nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
              "is now known as #{m.user.nick}."
    send_relay(message)
  end
  
  def relay_part(m, actionuser = nil)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == "#" + $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    if m.command == "PART"
      action = "parted the channel (#{m.message})"
    elsif m.command == "QUIT"
      action = "quit (#{m.message})"
    else
      action = "parted the channel"
    end
    message = "#{network} - #{m.user.nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
		          "has #{action}."
    send_relay(message)
  end
  
  def relay_join(m)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s
    return unless m.channel == "#" + $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{netname}]")
    message = "#{network} - #{m.user.nick} (#{m.user.mask.to_s.split("!")[1]}) " + \
              "has joined the channel."
    send_relay(message)
  end
  
  def send_relay(m)
    $bots.each do |network, bot|
      unless bot.irc.network == @bot.irc.network
        begin
          bot.irc.send("PRIVMSG ##{$config["servers"][network]["channel"]}" + \
                       " :#{m}")
        rescue => e
          # pass
        end
      end
    end
  end
end
