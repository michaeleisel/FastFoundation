extern crate cbindgen;

use std::io::Write;
use std::env;
use std::fs;
use std::fs::OpenOptions;

use cbindgen::Language;

fn main() {
    let header = autogen_header();
    let header = processed_header(&header);
    replace_contents(&header);
}

fn replace_contents(header: &str) {
    let path = "../../rust_bindings.h";
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .truncate(true)
        .create(true)
        .open(path)
        .unwrap();
    file.write_all(header.as_bytes()).unwrap();
}

fn autogen_header() -> String {
    let mut crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    crate_dir.push_str("/../main");
    let mut string = Vec::new();
    cbindgen::Builder::new()
      .with_crate(crate_dir)
      .with_language(Language::C)
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
