ruby-relay
==========
A ruby IRC relay bot that relays conversations across channels on many networks. Uses the Cinch framework.

Dependencies
------------
The following are required to run ruby-relay:

  * ruby (>=1.9)
  * cinch (https://github.com/cinchrb/cinch)

The following is required if you wish to use a network that does not support SASL:

  * cinch-identify (https://github.com/cinchrb/cinch-identify)

Install
-------

    gem install cinch cinch-identify
    git clone https://github.com/somasonic/ruby-relay.git
    cd ruby-relay
    cp config/config.yaml.example config/config.yaml

Then configure your bot by editing config/config.yaml. All configuration options are documented in the example config. Once done, you can start the bot using:

    ./ruby-relay

Support
-------
Please join #code on irc.interlinked.me (https://webchat.interlinked.me) and ping somasonic or GLolol.

Contributors
============
* somasonic (https://github.com/somasonic/) - wrote most of the code
* GLolol (https://github.com/GLolol) - wrote most of the documentation

License
=======
Licensed under the MIT License. See LICENSE file for more details.
