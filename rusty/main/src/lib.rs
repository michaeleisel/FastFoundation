extern crate libc;
extern crate jemallocator;

use std::os::raw::{c_void, c_char};
use std::ffi::CString;
use std::slice;
use libc::strlen;
use std::alloc::GlobalAlloc;
use jemallocator::Jemalloc;
use std::alloc::Layout;

#[no_mangle]
#[allow(unused_variables)]
pub extern fn FFORustDeallocate(ptr: *mut c_void, info: *mut c_void) {
    unsafe {
        CString::from_raw(ptr as *mut c_char);
    }
}

/*#[no_mangle]
pub extern fn FFOMalloc(size: usize) -> *mut u8 {
    let layout = Layout::from_size_align(size, 16).unwrap();
    let j = Jemalloc{};
    unsafe { j.alloc(layout) }
}*/

#[no_mangle]
pub extern fn FFOStrP

/*extern {
    CFStringGetCStringPtr(string: *const c_void, encoding: CFStringEncoding)
}*/

/*#[repr(C)]
pub struct FFOString {
    chars: *const c_char,
    len: u32,
}*/

#[no_mangle]
#[allow(unused_variables)]
pub extern fn FFOComponentsJoinedByString_Rust(values: *const *const c_char, values_len: u32, joiner: *const c_char) -> *const c_char {
    if values_len == 0 {
        return CString::new("").unwrap().into_raw();
    }
    let values_slice = unsafe { slice::from_raw_parts(values, values_len as usize) };
    let slices: Vec<&[u8]> = values_slice.iter().map(|value| {
        let len = unsafe { strlen(*value) };
        unsafe { slice::from_raw_parts(*value as *const u8, len) }
    }).collect();
    let joiner_len = unsafe { strlen(joiner) };
    let joiner = unsafe { slice::from_raw_parts(joiner as *const u8, joiner_len as usize) };
    let slices_len = slices.iter().fold(0, |sum, slice| sum + slice.len());
    let total_len = slices_len + joiner.len() * (slices.len() - 1);
    let mut result: Vec<u8> = Vec::with_capacity(total_len + 1); // allow for null-terminator
    for slice in slices[0..(slices.len() - 1)].iter() {
        result.extend_from_slice(slice as &[u8]);
        result.extend_from_slice(joiner);
    }
    result.extend_from_slice(slices.last().unwrap());
    unsafe { CString::from_vec_unchecked(result).into_raw() }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn join_helper(expected: &str, strs: &[&str], joiner: &str) {
        let mut pointers: Vec<*const c_char> = strs.iter().map(|s| {
            CString::new(*s).unwrap().into_raw() as *const c_char
        }).collect();
        let joiner_cstring = CString::new(joiner).unwrap().into_raw();
        let result = FFOComponentsJoinedByString_Rust(pointers.as_ptr(), pointers.len() as u32, joiner_cstring);
        let actual = unsafe { CString::from_raw(result as *mut c_char).into_string().unwrap() };
        assert_eq!(expected, actual);
        unsafe { CString::from_raw(joiner_cstring) };
        for ptr in pointers.iter_mut() {
            unsafe { CString::from_raw((*ptr) as *mut c_char) };
        }
    }

    #[test]
    fn join() {
        join_helper("", &[], "");
        join_helper("", &[""], "-");
        join_helper("foo", &["foo"], "-");
        join_helper("foo-bar", &["foo", "bar"], "-");
        join_helper("foobarbaz", &["foo", "bar", "baz"], "");
        join_helper("foo😂bar😂😂", &["foo", "bar", "😂"], "😂");
    }
}
