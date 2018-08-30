`find unicode/*`.split("\n").each do |file|
  str = IO.read(file).gsub(/^#include \"unicode\//, "#include \"")
  IO.write(file, str)
end
