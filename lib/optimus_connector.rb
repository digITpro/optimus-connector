require "optimus_connector/version"
require "optimus_connector/transaction_watcher"

module OptimusConnector
  def self.new(*args)
    TransactionWatcher.new(self.default_config.merge(*args))
  end

  def self.default_config
    {
        api_url: "http://www.google.com",
        app_relevant_sql_only: true
    }
  end
end