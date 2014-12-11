module OptimusConnector
  class Logger
    def self.log(exception)
      flag  = "[optimus_connector] "
      Rails.logger.error(flag + exception.inspect)
      Rails.logger.error(flag + exception.backtrace.join("\n#{flag}"))
    end
  end
end