extern crate cbindgen;

use std::io::Write;
use std::env;
use std::path::Path;
use std::fs;
use std::fs::OpenOptions;

fn main() {
    let header = autogen_header();
    let header = processed_header(&header);
    replace_contents(&header);
}

fn replace_contents(header: &str) {
    let path = "../rust_bindings.h";
    fs::remove_file(path).unwrap();
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .open(path)
        .unwrap();
    file.write_all(header.as_bytes()).unwrap();
}

fn autogen_header() -> String {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let mut string = Vec::new();
    let config = cbindgen::Config::from_root_or_default(Path::new(&crate_dir));
    cbindgen::Builder::new()
      .with_crate(crate_dir)
      .with_config(config)
      .generate()
      .unwrap()
      .write(&mut string);
    String::from_utf8(string).unwrap()
}

fn processed_header(header: &str) -> String {
    // Remove all auto-generated includes
    let mut lines: Vec<&str> = header.split("\n").filter(|line| {
        !line.starts_with("#include ")
    }).collect();
    lines.insert(0, "#import <Foundation/Foundation.h>");
    lines.join("\n")
}
