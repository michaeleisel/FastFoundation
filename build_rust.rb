raise "Must be called from same dir as script" unless __dir__ == Dir.pwd
cargo_root = "~/.cargo/bin"
ENV.delete_if do |var|
  var != "PATH"
end
ENV["PATH"] += ":~/.cargo/bin"
success = system(
	"""
	cd rusty \
	&& #{cargo_root}/cargo build --release --target aarch64-apple-ios \
	&& cp target/aarch64-apple-ios/release/librusty.a ../rusty.a
""")
abort unless success
