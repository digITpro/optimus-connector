require "optimus_connector/version"
require "optimus_connector/transaction_watcher"
require "optimus_connector/server_watcher"

module OptimusConnector
  def self.new(*args)
    TransactionWatcher.new
    ServerWatcher.new
  end

  def self.connector
    @connector ||= Connector.new(config)
  end

  def self.config
    config = YAML::load(File.open("#{Rails.root}/config/optimus_connector.yml"))[Rails.env]
    config.merge!(api_url: "http://www.google.com")
    config = config.with_indifferent_access
    config
  end
end