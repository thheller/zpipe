require './msg_pipe.rb'
require './handler.rb'

if ARGV.length != 1
  puts "Usage: bundle exec ruby zworker.rb <number_of_processes>"
  exit 1
end

num_workers = ARGV[0].to_i

num_workers.times do 
  fork do
    MsgPipe.worker('tcp://127.0.0.1:7894', Handler.new) do |worker|
      puts "Worker: #{Process.pid} started ..."
      worker.work! # never returns
    end

    exit 0
  end
end

Process.waitall
