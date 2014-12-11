require "optimus_connector/connector"

module OptimusConnector
  class ServerWatcher
    WATCHED_PROCESSES = %w(ruby postgres god rsync nginx)
    def initialize(config)
      @config = config
      @connector = Connector.new(@config)
      run
    end

    def run
      t = Thread.new do
        i = 0
        interval = 5
        while true
          @connector.post("/trackings/server_status", poll_server_info(i == 0))
          i = i == 23 ? 0 : i+=1
          sleep(interval)
        end
      end
      t.abort_on_exception = true
    end

    #######################
    ### Private methods ###
    #######################

    private

    def poll_server_info(long = false)
      stats = {time: Time.current, total_memory: poll_total_memory, used_memory: poll_used_memory, cpu_load: poll_cpu_load, processes: poll_processes}
      stats.merge!(distribution: poll_distribution, available_cpus: poll_available_cpus, security_updates: poll_security_updates) if long
      stats
    end

    def poll_distribution
      `lsb_release -ds`.chomp
    end

    def poll_available_cpus
      # output format: 4, cores are counted as one each
      `cat /proc/cpuinfo | grep processor | wc -l`.chomp
    end

    def poll_security_updates
      `/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2`.chomp
    end

    def poll_total_memory
      # output format: 15G
      `free -mhg | awk '/Mem:/ { print $2 }'`.chomp
    end

    def poll_used_memory
      # output format: 15G
      `free -mhg | awk '/buffers\\/cache/ { print $3 }'`.chomp
    end

    def poll_cpu_load
      # percentage of the overall CPU load in percentage
      # output format 15
      `top -bn 2 -d 1 | grep '^%Cpu' | tail -n 1 | gawk '{print $2+$4+$6}'`.chomp
    end

    def poll_processes
      # extract PID, USER, %CPU, %MEM and COMMAND from unix top command for specific processes
      # %CPU usage is returned as a percentage of a single CPU. For an overall percentage of CPU use, it should be divided by the numbers of processor/cores
      # wait for two iterations of top command because the first one will calculate results from system boot until now
      # the subsequent iterations will calculate results from the last iteration until now

      top_extract = `top -d 1 -bn 2 | grep  -w -E "#{WATCHED_PROCESSES.join('|')}" | awk '{ printf("%-s;%-s;%-s;%-s;%-s\\n", $1, $2, $9, $10, $12); }'`
      processes = []
      top_extract.each_line do |line|
        pid, user, cpu, mem, cmd = line.split(';')
        # override results from the first iteration
        processes = processes.reject{|p| p[:pid] == pid} << {pid: pid, user: user, cpu: cpu, mem: mem, cmd: cmd.chomp}
      end
      processes
    end
  end
end