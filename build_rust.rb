raise "Must be called from same dir as script" unless __dir__ == Dir.pwd
cargo_root = "~/.cargo/bin"
is_release = ENV["CONFIGURATION"] == "Release"
ENV.delete_if do |var|
  var != "PATH"
end
ENV["PATH"] += ":~/.cargo/bin"
release_flag = is_release ? "--release" : "" # aarch64-apple-ios
dir = "rusty/main"
lib_path = "../rusty.a"
`rm #{dir}/#{lib_path}`
target = "x86_64-apple-ios"
success = system(
	"""
	cd #{dir} \
	&& #{cargo_root}/cargo build --release --target #{target} \
	&& cp target/#{target}/release/librusty.a #{lib_path} \
  && cd ../headergen \
  && #{cargo_root}/cargo run --release
""")
abort unless success
