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
  
  
  def relay(m)
    return if m.user.nick == @bot.nick
    network = Format(:bold, "[#{@bot.irc.network.name}]")
    if m.action?
      message = "#{network} * #{m.user.nick} #{m.action_message}"
    else
      message = "#{network} <#{m.user.nick}> #{m.message}"
    end
    send_relay(message)
  end
  
  def relay_nick(m)
    return if m.user.nick == @bot.nick
    network = Format(:bold, "[#{@bot.irc.network.name}]")
    message = "#{network} - #{m.user.last_nick} (#{m.user.mask("%u@%h")}) " + \
              "is now known as #{m.user.nick}."
    send_relay(message)
  end
  
  def relay_part(m, actionuser = nil)
    return if m.user.nick == @bot.nick
    network = Format(:bold, "[#{@bot.irc.network.name}]")
    if m.command == "PART"
      action = "parted the channel (#{m.message})"
    elsif m.command == "QUIT"
      action = "quit"
    else
      action = "parted the channel"
    end
    message = "#{network} - #{m.user.nick} (#{m.user.mask("%u@%h")}) " + \
		          "has #{action}."
    send_relay(message)
  end
  
  def relay_join(m)
    return if m.user.nick == @bot.nick
    network = Format(:bold, "[#{@bot.irc.network.name}]")
    message = "#{network} - #{m.user.nick} (#{m.user.mask("%u@%h")}) " + \
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
