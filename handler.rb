# simple handler class
# every public method will be reachable via rpc

class Handler

  def add(a, b)
    a + b
  end

  def hi
    'hello'
  end

  def echo(string)
    string
  end

  def sleepy
    sleep(1)
    true
  end

  def get_your_mysql_on(some_id)
    puts "calling mysql: #{some_id}"
    puts "faking some work"
    fake_some_work(5)
  end

  def rock_some_redis(some_id)
    puts "calling redis: #{some_id}"
    fake_some_work
  end

  def contact_your_homies(some_id, some_mail)
    puts 'contacting ma homies'
    fake_some_work
  end

  def go_fetch(url)
    puts "fetching: #{url}" # not really
    fake_some_work 
  end

  def fake_some_work(x = 0)
    time = x + rand()
    puts "sleeping: #{time}"
    sleep(time)
    time
  end

  def who_are_you
    "Hi, I'm #{Process.pid}" 
  end

  def throw
    raise StandardError, 'hell'
  end

  private

  def private_method
    'oh no'
  end
end

