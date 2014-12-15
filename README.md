# OptimusConnector

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'optimus_connector'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install optimus_connector

Add `OptimusConnector.new` in initializers/optimus_connector.rb

Add your configuration in config/optimus_connector.yml, ex:

```
default: &defaults
  api_key: "YourSecretKey"
  application_name: "YourAppName"

production:
  <<: *default

development:
  <<: *default
```

## Usage

TODO: Write usage instructions here

TODO mention to set config.active_support.deprecation to :notify in production.rb in order to catch deprecation warnings

## Contributing

1. Fork it ( https://github.com/[my-github-username]/optimus_connector/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
