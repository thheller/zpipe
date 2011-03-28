require './msg_pipe.rb'
require './handler.rb'

num_workers = 5
num_workers.times do 

  fork do
    begin
      MsgPipe.run do |pipe|

        queue = pipe.socket(ZMQ::PULL)
        queue.connect("ipc://task_queue.ipc")

        results = pipe.socket(ZMQ::PUSH)
        results.connect("ipc://task_results.ipc")

        handler = Handler.new()

        puts "Working running ..."

        # receives [task_id, task_name, method, [args]] messages
        # lets handler to the work
        # sends [task_id, task_name, result] off to the results
        while msg = queue.recv_string
          task_id, task_name, method, args = MessagePack.unpack(msg)

          result = handler.public_send(method, *args)

          results.send_string([task_id, task_name, result].to_msgpack)
        end
      end

      exit 0
    rescue => e
      p e
      exit 1
    end
  end
end

Process.waitall
