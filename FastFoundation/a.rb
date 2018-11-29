require 'parallel'

loop do
  Parallel.each(1.upto(100000000), in_threads: 4) do |_|
    sum = 0
    1.upto(100000000).each do |i|
      sum += i
    end
    puts sum
  end
end
