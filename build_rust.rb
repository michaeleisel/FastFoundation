raise "Must be called from same dir as script" unless __dir__ == Dir.pwd
cargo_root = "~/.cargo/bin"
is_release = ENV["CONFIGURATION"] == "Release"
ENV.delete_if do |var|
  var != "PATH"
end
ENV["PATH"] += ":~/.cargo/bin"
release_flag = is_release ? "--release" : ""
success = system(
	"""
	cd rusty/main \
	&& #{cargo_root}/cargo build #{release_flag} --target aarch64-apple-ios \
	&& cp target/aarch64-apple-ios/release/librusty.a ../rusty.a \
  && cd ../headergen \
  && #{cargo_root}/cargo run --release
""")
abort unless success
