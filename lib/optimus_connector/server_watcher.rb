require "optimus_connector/connector"

module OptimusConnector
  class ServerWatcher
    def initialize(config)
      @config = config
      @connector = Connector.new(@config)
      run
    end

    def run
      Thread.new do
        i = 0
        interval = 60
        while true
          @connector.post("/trackings/server_status", poll_server_info(i == 0))
          i = i == 23 ? 0 : i+=1
          sleep(interval)
        end
      end

    end

    #######################
    ### Private methods ###
    #######################

    private

    def poll_server_info(long = false)
      total_ram = `free -mhg | awk '/Mem:/ { print $2 }'`.gsub("\n",'')
      used_ram = `free -mhg | awk '/buffers\\/cache/ { print $3 }'`.gsub("\n",'')
      stats = {time: Time.current, total_ram: total_ram, used_ram: used_ram}
      if long
        distribution = `lsb_release -ds`.gsub("\n",'')
        cpus = `cat /proc/cpuinfo | grep processor | wc -l `.gsub("\n",'')
        security_updates = `/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2`.gsub("\n",'')
        stats.merge!(distribution: distribution, cpus: cpus, security_updates: security_updates)
      end
      stats
    end

  end
end