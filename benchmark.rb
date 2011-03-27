require './msg_pipe.rb'
require 'benchmark'

# blindly stolen from tobi ;)

expectations = []

# make this predictable
srand(0)

# Build a series of 5000 tests, every test has format [expectation, method, *args]
expectations = (0..5000).collect do
  case rand(3)
  when 0
    num = rand(1000000)
    [num+num, :add, num, num]
  when 1
    ['hello', :hi]
  when 2
    data = '.' * rand(10000)
    [data, :echo, data]
  end	
end

# Create 5 concurrent workers to pound the server with the fuzz test
pids = (0..4).collect do 
  fork do 
    MsgPipe.client('tcp://localhost:7893') do |client|
      ms = Benchmark.realtime do 
        expectations.each do |expectation, method, *args|
          raise 'fail' unless client.call(method, *args) == expectation				
        end
      end

      puts "benchmark finished in #{ms}s"
    end

    exit 0
  end
end

# Wait for all forks to complete
Process.waitall

