# Configuration Guide

To have ruby-relay working properly, it must be properly configured!

## bot: block
This block contains the basic information for your relayer.

*Italicized* fields can be set on a per-network basis.

* ***nick:*** The nickname the relayer will use.
* ***user:*** The username/ident the relayer will use.
* ***realname:*** The realname the relayer will use.
* ***saslname:*** The username to use for SASL authentication. This will *only* work on networks with SASL enabled.
* ***nickservpass:*** The password used to identify to services.
* ***msgspersec:*** Defines the maximum amount of messages the bot will send in a second (to prevent itself from flooding off). Defaults to per-ircd smart defaults if not set.
* **usecolour:** Toggles colouring of nicks and networks in relayed messages.
* **nohighlights:** Prevent unwanted highlights by toggling whether to prepend a dash in front of relayed nicks.
* **privmsgonly:** Set to true to only relay privmsgs (as opposed to joins/parts/quits/privmsgs/nicks/kicks/quits).
* **nohostmasks:** Set to true to disable displaying hostmasks in joins and other events.

## admins: block
Defines a list of hostnames that are able to use `!rehash`.

## servers: block
Here, each network is defined in a separate block.

* **server:** The server for the relayer to connect to.
* **port:** The port for the relayer to connect to.
* **ssl:** Toggles whether to use SSL (secure connection).
* **sasl:** Toggles whether to use SASL authentication.
* **channel:** The channel for the relayer to relay to. Channel names should be quoted to prevent them from being read as comments.
* **password:** (optional) Defines the server password that should be used, for use with a BNC, etc.

## ignore: block
This block specifies any nicks that should be ignored by the relayer. (e.g. services bots)

* **ignoreprivmsg**: Toggle whether to relayer should ignore privmsgs. If false, it will ignore only joins/parts/quits/nicks/modes.
* **nicks**: List the nicks that should be ignored.

## events: block
This block allows enabling/disabling individual non-privmsg events, for greater customizability. This is overriden by bots::privmsgonly

* **disable(joins|parts|kicks|nicks|modes|quits)**: Toggles whether this kind of message will be relayed.
