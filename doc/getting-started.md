# Getting Started
## Introduction
First of all, thanks for trying out ruby-relay! The first thing you'll probably want to do now is set it up. All configuration options are documented in ``config.yaml.example`` and the [Configuration Guide](/doc/configuration-guide.md), so it should be pretty straightforward.

Dependencies and installation instructions are listed in the main README file.

## Commands
ruby-relay is quite simple and only has a few public commands.

`!nicks [&lt;network&gt;]`
* Replies (in private notice) a list of users present in the relay. If <network> is specified, list only the users on that network. Do note that this output can be quite long on relays with many networks!

`!stats`
* Returns the amount of users across the relay.

`!networks`
* Returns a list of connected networks.

`!channels`
* Returns a list of networks/channels linked through the relay.

`!rehash`
* Reloads the configuration file. This is limited to those listed in the `admins:` config section.

`!uptime`
* Returns uptime information.
