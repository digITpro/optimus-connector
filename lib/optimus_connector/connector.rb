require "optimus_connector/logger"

module OptimusConnector
  class Connector
    attr_reader :queue

    def initialize(config)
      @config = config
      @queue ||= []
      schedule_queue_processing
    end

    def enqueue!(path, data)
      # TODO block enqueue! while processing
      data.merge!(api_key: @config[:api_key], app_name: @config[:application_name], environment_name: Rails.env)
      @queue << {path: path, data: data}
    end

    private

    def schedule_queue_processing
      Thread.new do
        while true
          process_queue!
          sleep(30)
        end
      end
    end

    def process_queue!
      if @queue.any?
        grouped_queue = @queue.group_by{ |q| q[:path] }.each{ |_, v| v.map!{ |h| h[:data] } }
        grouped_queue.each{|k,v| post(k, v)}
        @queue = []
      end
    end

    def post(path, data)
      uri = URI.parse(@config[:api_url] + path)
      Net::HTTP.start(uri.host, uri.port) do |http|
        post = Net::HTTP::Post.new(uri.path)
        post.content_type = "application/json"
        post.body = data.to_json
        http.request(post)
      end
    rescue => exception
      Logger.log(exception)
    end
  end
end