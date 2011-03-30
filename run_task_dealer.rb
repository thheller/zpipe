require './msg_pipe.rb'

class Task
  def initialize(ident, task_id, tasks, deadline)
    @ident = ident
    @task_id = task_id
    @tasks = tasks
    @deadline = deadline
    @results = {}

    @pending_tasks = tasks.keys
  end

  attr_reader :ident, :task_id, :tasks, :deadline, :results, :pending_tasks

  def add_result(task_name, result)
    @results[task_name] = result
    @pending_tasks.delete(task_name)
  end

  def complete?
    @pending_tasks.empty?
  end

  def timeout?
    !!(@deadline < Time.now.to_f)
  end
end

class TaskMaster
  def initialize()
    @pending_tasks = [] 
  end

  def register_task(client_ident, task_id, tasks, timeout)
    @pending_tasks << Task.new(client_ident, task_id, tasks, Time.now.to_f + timeout)
  end

  def timeouts()
    @pending_tasks.reject! do |task|
      if task.timeout?
        yield(task)
        true
      else
        false
      end
    end
  end

  def task_progress(task_id, task_name, result)
    task = @pending_tasks.detect { |it| it.task_id == task_id }

    if not task
      puts "received result for task that timed out: #{task_name}:#{result.inspect}, ignored!"
    else
      task.add_result(task_name, result)

      if task.complete?
        @pending_tasks.delete(task)
        return task
      end
    end

    nil
  end
end

MsgPipe.run do |pipe|

  frontend = pipe.socket(ZMQ::XREP)
  frontend.bind('tcp://*:7896')

  task_queue = pipe.socket(ZMQ::PUSH)
  task_queue.bind('ipc://task_queue.ipc')

  task_results = pipe.socket(ZMQ::PULL)
  task_results.bind('ipc://task_results.ipc')

  task_master = TaskMaster.new()

  while true
    if select_result = ZMQ.select([frontend, task_results], [], [], 0.1)
      select_result[0].each do |it|
        case it
        when frontend
          client_ident = frontend.recv # rep -> xrep
          frontend.recv # empty sep "" rep -> xrep

          task_id, tasks, timeout = MessagePack.unpack(frontend.recv)

          puts "received task: #{task_id} willing to wait: #{timeout}secs"

          task_master.register_task(client_ident, task_id, tasks, timeout)
          tasks.each_pair do |task_name, task_call|
            puts " -> #{task_name}: #{task_call.inspect}"
            task_queue.send([task_id, task_name, task_call[0], task_call[1]].to_msgpack)
          end

        when task_results
          task_id, task_name, result = MessagePack.unpack(task_results.recv)

          puts "task: #{task_id} received result for #{task_name}"
          p result

          if task = task_master.task_progress(task_id, task_name, result)
            puts "task: #{task_id} is done"

            # reply back to sender, wrap in REP envelope
            frontend.send(task.ident, ZMQ::SNDMORE)
            frontend.send("", ZMQ::SNDMORE)
            frontend.send([task.results, []].to_msgpack)
          end
        end
      end
    else # timeout and noone said anything
      task_master.timeouts do |task|
        puts "task: #{task.task_id} is past its deadline, returning what i got"

        frontend.send(task.ident, ZMQ::SNDMORE)
        frontend.send("", ZMQ::SNDMORE)
        frontend.send([task.results, task.pending_tasks].to_msgpack)
      end
    end
  end
end
