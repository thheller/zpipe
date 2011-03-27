require './msg_pipe.rb'

if ARGV.length != 2
  puts "Usage: bundle exec ruby run_multiple.rb <number_of_processes> <number_of_requests>"
  exit 1
end

start = Time.now.to_f

num_processes = ARGV[0].to_i
num_requests = ARGV[1].to_i

puts "Starting #{num_processes} clients with #{num_requests} requests each."

num_processes.times do
  fork do
    MsgPipe.client("tcp://localhost:7893") do |client|
      puts "Started"

      num_requests.times do |x|
        client.call(:sleepy) # actually just sleeps for a sec, see handler.rb
        puts "#{Process.pid}: Request #{x} done"
      end
    end

    exit 0
  end
end

Process.waitall

puts "Finished after: #{Time.now.to_f - start}"
