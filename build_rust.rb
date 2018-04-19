raise "Must be called from same dir as script" unless __dir__ == Dir.pwd
success = system(
	"""
	cd rusty \
	&& cargo build --target aarch64-apple-ios \
	&& cp target/aarch64-apple-ios/release/librusty.a ../rusty.a
""")
abort unless success
