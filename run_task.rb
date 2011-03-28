require './msg_pipe.rb'

MsgPipe.contact_dealer('tcp://localhost:7896') do |dealer|

  start = Time.now.to_f

  task = dealer.new_task()
  # call get_your_mysql_on(123) and name that task: mysql
  task.add(:mysql, :get_your_mysql_on, 123)
  task.add(:redis, :rock_some_redis, 456)
  task.add(:email, :contact_your_homies, 123, 'info@zilence.net')
  task.add(:web, :go_fetch, 'http://www.shopfiy.com')

  task.go!(2) # mysql actually takes 5 sec, so we never get that

  # task.go!(6) # let all tasks actually finish

  puts "Are all tasks done?"
  p task.all_done?

  puts "These are missing:"
  p task.timeouts

  p task.results[:mysql]
  p task.results[:redis]
  p task.results[:email]
  p task.results[:web]

  total = task.results.values.inject(0) { |x,i| x += i }

  puts "total sum of work done: #{total}sec"
  puts "took a total of: #{Time.now.to_f - start}sec"
  puts "will be very close to the max runtime of a indiviual task or the timeout"
end
