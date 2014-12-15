require "optimus_connector/version"
require "optimus_connector/transaction_watcher"
require "optimus_connector/server_watcher"

module OptimusConnector
  def self.new(*args)
    config = YAML::load(File.open("#{Rails.root}/config/optimus_connector.yml"))[Rails.env]
    config.merge!(self.default_config)
    TransactionWatcher.new(config)
    ServerWatcher.new(config)
  end

  def self.default_config
    {"api_url" => "http://www.google.com"}
  end
end