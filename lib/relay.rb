####
## ruby-relay
## relay plugin
##
## Copyright (c) 2013 Andrew Northall
##
## MIT License
## See LICENSE file for details.
####

require 'digest/md5'

class RelayPlugin
  include Cinch::Plugin
  
  listen_to :message, method: :relay
  listen_to :part, method: :relay_part
  listen_to :quit, method: :relay_quit
  listen_to :kick, method: :relay_kick
  listen_to :join, method: :relay_join
  listen_to :nick, method: :relay_nick
  listen_to :mode, method: :relay_mode
  listen_to :join, method: :relay_connect
  listen_to :leaving, method: :relay_disconnect
  
  
  match "nicks", method: :nicks
  match /nicks (\S+)/, method: :nicks
  match "stats", method: :stats
  match "networks", method: :networks
  match "channels", method: :channels
  match "rehash", method: :rehash
  
  def is_admin?(user)
    return false if $config["admins"].nil?
    if $config["admins"].class == String
      if Cinch::Mask.new($config["admins"]) =~ user.mask
        return true
      end
    elsif $config["admins"].class == Array
      $config["admins"].each do |m|
        if Cinch::Mask.new(m) =~ user.mask
          return true
        else
          next
        end
      end
    end
    return false
  end
  
  def rehash(m)
    return unless is_admin?(m.user)
    old_config = $config
    new_config = YAML.load_file("config/config.yaml")
    
    # Make server names all downcase
    servers = {}
    new_config["servers"].each do |k, v|
      servers.merge!({k.downcase => v})
    end
    new_config["servers"] = servers

    # Make ignore names all downcase
    names = new_config["ignore"]["nicks"].map { |v| v.downcase }
    new_config["ignore"]["nicks"] = names
    
    old_config["servers"].each do |name, server|
      if new_config["servers"].has_key? name
        $bots[name].nick = new_config["servers"][name]["nick"] || new_config["bot"]["nick"]
        $bots[name].channels.each do |c|
          c.part unless c.name.to_s =~ /#{new_config["servers"][name]["channel"]}/
          $bots[name].Channel(new_config["servers"][name]["channel"]).join
        end
      else
        $bots[name].quit
        $bots.delete name
      end
    end
    
    new_config["servers"].each do |name, server|
      next if old_config["servers"].has_key? name
      bot = Cinch::Bot.new do
        configure do |c|
          c.nick = server["nick"] || new_config["bot"]["nick"]
          c.user = server["user"] || new_config["bot"]["user"]
          c.realname = server["realname"] || new_config["bot"]["realname"]
          c.server = server["server"]
          c.ssl.use = server["ssl"]
          c.port = server["port"]
          c.channels = [server["channel"]]
          opts = server["msgspersec"] || new_config["bot"]["msgspersec"] || nil
          c.messages_per_second = opts unless opts.nil?
          nsname = server["nickservname"] || new_config["bot"]["nickservname"] || c.nick
          unless server["sasl"] == false
            c.sasl.username = nsname
            c.sasl.password = server["nickservpass"] || new_config["bot"]["nickservpass"]
            c.plugins.plugins = [RelayPlugin]
          else
            c.plugins.plugins = [RelayPlugin, Cinch::Plugins::Identify]
            c.plugins.options[Cinch::Plugins::Identify] = {
              :password => new_config["bot"]["nickservpass"],
              :type     => :nickserv,
            }
          end
        end
      end
      bot.loggers.clear
      bot.loggers << RelayLogger.new(name, File.open("log/irc-#{name}.log", "a"))
      bot.loggers << RelayLogger.new(name, STDOUT)
      bot.loggers.level = :info
      $bots[name] = bot
      $threads << Thread.new { bot.start }
    end
    
    $config = new_config
    m.reply "done!"
  end
  
  def ignored_nick?(nick)
    if $config["ignore"]["nicks"].include? nick.downcase
      return true
    else
      return false
    end
  end
  
  def relay(m)
    return if m.user.nick == @bot.nick
    if ignored_nick?(m.user.nick.to_s)
      return if $config["ignore"]["ignoreprivmsg"] 
    end
    netname = @bot.irc.network.name.to_s.downcase
    return if m.channel.nil?
    return unless m.channel.name.downcase == $config["servers"][netname]["channel"].downcase
    
    network = Format(:bold, "[#{colorise(netname)}]")
    nick = colorise(m.user.nick)
    nick = "-" + nick if $config["bot"]["nohighlights"]
    
    if m.action?
      message = "#{network} * #{nick} #{m.action_message}"
    else
      message = "#{network} <#{nick}> #{m.message}"
    end
    
    send_relay(message)
  end
  
  def relay_mode(m)
    return if $config["bot"]["privmsgonly"]
    return if m.params.nil?
    return if @bot.irc.network.name.nil? #not connected yet
    netname = @bot.irc.network.name.to_s.downcase
    return unless m.params[0].downcase == $config["servers"][netname]["channel"].downcase
    if m.user.nil?
      user = m.raw.split(":")[1].split[0]
    else
      return if ignored_nick?(m.user.nick.to_s)
      if $config["bot"]["nohostmasks"]
        user = colorise(m.user.nick)
      else
        user = "#{colorise(m.user.nick)} (#{m.user.mask.to_s.split("!")[1]})"
      end
    end
    network = Format(:bold, "[#{colorise(netname)}]")
    message = "#{network} - #{user} set mode #{m.params[1..-1].join(" ")} on #{m.params[0]}"
    send_relay(message)
  end
  
  def relay_nick(m)
    return if $config["bot"]["privmsgonly"]
    return if m.user.nick == @bot.nick
    return if ignored_nick?(m.user.nick.to_s)
    return if ignored_nick?(m.user.last_nick.to_s)
    netname = @bot.irc.network.name.to_s.downcase
    return unless m.user.channels.include? $config["servers"][netname]["channel"]
    network = Format(:bold, "[#{colorise(netname)}]")
    message = "#{network} - #{colorise(m.user.last_nick)} is now known as #{colorise(m.user.nick)}"
    send_relay(message)
  end
  
  def relay_part(m)
    return if $config["bot"]["privmsgonly"]
    return if m.user.nick == @bot.nick
    return if ignored_nick?(m.user.nick.to_s)
    netname = @bot.irc.network.name.to_s.downcase
    return if m.channel.nil?
    return unless m.channel.name.downcase == $config["servers"][netname]["channel"].downcase
    network = Format(:bold, "[#{colorise(netname)}]")
    if m.message.to_s.downcase == m.channel.name.to_s.downcase
      if $config["bot"]["nohostmasks"]
        message = "#{network} - #{colorise(m.user.nick)} has parted #{m.channel.name}"
      else
        message = "#{network} - #{colorise(m.user.nick)} (#{m.user.mask.to_s.split("!")[1]}) " + \
		            "has parted #{m.channel.name}"
      end
    else
      if $config["bot"]["nohostmasks"]
        message = "#{network} - #{colorise(m.user.nick)} has parted #{m.channel.name} (#{m.message})"
      else
        message = "#{network} - #{colorise(m.user.nick)} (#{m.user.mask.to_s.split("!")[1]}) " + \
		            "has parted #{m.channel.name} (#{m.message})"
      end
    end
    send_relay(message)
  end
  
  def relay_quit(m)
    return if $config["bot"]["privmsgonly"]
    return if ignored_nick?(m.user.nick.to_s)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s.downcase
    network = Format(:bold, "[#{colorise(netname)}]")
    message = "#{network} - #{colorise(m.user.nick)} has quit (#{m.message})"
    send_relay(message)
  end
    
  def relay_kick(m)
    return if $config["bot"]["privmsgonly"]
    netname = @bot.irc.network.name.to_s.downcase
    return if m.channel.nil?
    return unless m.channel.name.downcase == $config["servers"][netname]["channel"].downcase
    if m.params[1].downcase == @bot.nick.downcase
      Channel($config["servers"][netname]["channel"]).join
      return
    end
    network = Format(:bold, "[#{colorise(netname)}]")
    if $config["bot"]["nohostmasks"]
      message = "#{network} - #{colorise(m.params[1])} has been kicked from #{m.channel.name} by" + \
                " #{m.user.nick} (#{m.message})"
    else
      message = "#{network} - #{colorise(m.params[1])} (#{User(m.params[1]).mask.to_s.split("!")[1]}) " + \
		            "has been kicked from #{m.channel.name} by #{m.user.nick} (#{m.message})"
    end
    send_relay(message)
  end
  
  def relay_connect(m)
    elapsed_time = Time.now.to_i - $start
    return if elapsed_time < 60
    netname = @bot.irc.network.name.to_s.downcase
    return if m.channel.nil?
    return unless m.channel.name.downcase == $config["servers"][netname]["channel"].downcase
    return unless m.user.nick == @bot.nick
    network = Format(:bold, "[#{colorise(netname)}]")
    send_relay("#{network} *** Relay joined to #{m.channel.name}")
  end
  
  def relay_disconnect(m, user)
    return unless user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s.downcase
    network = Format(:bold, "[#{colorise(netname)}]")
    send_relay("#{network} *** Relay parted/disconnected. Attempting to reconnect/rejoin...")
  end
  
  def relay_join(m)
    return if $config["bot"]["privmsgonly"]
    return if ignored_nick?(m.user.nick.to_s)
    return if m.user.nick == @bot.nick
    netname = @bot.irc.network.name.to_s.downcase
    return if m.channel.nil?
    return unless m.channel.name.downcase == $config["servers"][netname]["channel"].downcase
    network = Format(:bold, "[#{colorise(netname)}]")
    if $config["bot"]["nohostmasks"]
      message = "#{network} - #{colorise(m.user.nick)} has joined #{m.channel.name}"
    else
      message = "#{network} - #{colorise(m.user.nick)} (#{m.user.mask.to_s.split("!")[1]}) " + \
                "has joined #{m.channel.name}"
    end
    send_relay(message)
  end
  
  def nicks(m, unetwork = nil)
    target = m.user

    unless unetwork.nil?
      unless $config["servers"].keys.map { |k| k.downcase }.include? unetwork.downcase
        target.notice "Network #{unetwork} not found."
        return
      end
    end
    
    total_users = 0
    unique_users = []
    disconnected = []
    
    $bots.each do |network, bot|
      unless unetwork.nil?
        next unless network =~ /#{unetwork}/i
      end
      
      chan = $config["servers"][network]["channel"]
      begin
        users = bot.Channel(chan).users
        users_with_modes = Array.new
      
        users.each do |nick, modes|
          if modes.include?("o")
            users_with_modes << "@" + nick.to_s
          elsif modes.include?("h")
            users_with_modes << "%" + nick.to_s
          elsif modes.include?("v")
            users_with_modes << "+" + nick.to_s
          else
            users_with_modes << nick.to_s
          end
          unique_users << nick unless unique_users.include?(nick)
        end
      
        total_users += users.size
      
        target.notice("#{users.size} users in #{chan} on #{network}: #{users_with_modes.join(", ")}.")
      rescue => e
        disconnected << network
      end
    end
    if unetwork.nil?
      target.notice("Total users across #{$bots.size} channels: #{total_users}. Unique nicknames: #{unique_users.size}.")
    end
    
    unless disconnected.empty?
      target.notice("Disconnected from #{disconnected.size} networks: #{disconnected.join(", ")}.")
    end
  end
  
  def stats(m)
    total_users = 0
    unique_users = []
    disconnected = []
    
    $bots.each do |network, bot|
      chan = $config["servers"][network]["channel"]
      begin
        users = bot.Channel(chan).users
        total_users += users.size
        users.each do |nick, modes|
          unique_users << nick unless unique_users.include?(nick)
        end
      rescue => e
        disconnected << network
      end
    end
    m.reply("Total users across #{$bots.size} channels: #{total_users}. Unique nicknames: #{unique_users.size}.")
    sleep 0.1
    relay_cmd_reply("Total users across #{$bots.size} channels: #{total_users}. Unique nicknames: #{unique_users.size}.")
    
    unless disconnected.empty?
      m.reply("Disconnected from #{disconnected.size} networks: #{disconnected.join(", ")}.")
      sleep 0.1
      relay_cmd_reply("Disconnected from #{disconnected.size} networks: #{disconnected.join(", ")}.")
    end
  end
  
  def networks(m)
    reply = "I am connected to #{$bots.size} networks: #{$bots.keys.join(", ")}."
    m.reply reply
    sleep 0.1
    relay_cmd_reply(reply)
  end
  
  def channels(m)
    pre_join_strs = Array.new
    $bots.keys.each do |network|
      pre_join_strs << "#{network}/#{$config["servers"][network]["channel"]}"
    end
    
    reply = "I am in #{$bots.size} channels: #{pre_join_strs.join(", ")}."
    m.reply reply
    sleep 0.1
    relay_cmd_reply(reply)
  end
  
  def relay_cmd_reply(text)
    netname = @bot.irc.network.name.to_s.downcase
    network = Format(:bold, "[#{colorise(netname)}]")
    relay_reply = "#{network} <#{@bot.nick}> #{text}"
    send_relay(relay_reply)
  end
  
  def send_relay(m)
    $bots.each do |network, bot|
      unless bot.irc.network.name.to_s.downcase == @bot.irc.network.name.to_s.downcase
        begin
          bot.irc.send("PRIVMSG #{$config["servers"][network]["channel"]}" + \
                       " :#{m}")
        rescue => e
          # pass
        end
      end
    end
  end

	def colorise(text) 
    return text unless $config["bot"]["usecolour"]
    colours = ["\00303", "\00304", "\00305", "\00306",
               "\00307", "\00308", "\00309", "\00310", 
               "\00311", "\00312", "\00313"]

    floathash = Digest::MD5.hexdigest(text.to_s).to_i(16).to_f
    index = floathash % 10
    return "#{colours[index]}#{text}\3"
  end
end
