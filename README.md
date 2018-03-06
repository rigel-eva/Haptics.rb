# Haptics.rb - A haptic control client

This gem provides a way to control haptic devices connected to a server remotely.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'buttplugrb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install buttplugrb

## Usage

You can get client up and running like this:

```ruby
require "buttplugrb"
client=Buttplug::Client.new("wss://localhost:12345/buttplug")
``` 

You can view some additional examples in the Examples Folder!

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
