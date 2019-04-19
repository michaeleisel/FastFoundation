extern crate libc;

use std::os::raw::{c_void, c_char};
use std::ffi::CString;
use std::slice;
use libc::strlen;



#[no_mangle]
#[allow(unused_variables)]
pub extern fn FFORustDeallocate(ptr: *mut c_void, info: *mut c_void) {
    unsafe {
        CString::from_raw(ptr as *mut c_char);
    }
}

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

pub struct Callbacks {
    dict_start: &'static Fn(),
    dict_end: &'static Fn(),
    array_start: &'static Fn(),
    array_end: &'static Fn(),
    string: &'static Fn(&str),
    int64: &'static Fn(i64),
    double: &'static Fn(f64),
}

fn align(ptr: *const u8, alignment: usize) -> *const u8 {
    // todo: fix
    ptr// pt % alignment
}

extern "C" {
    fn process_chars(start: *const u8, len: usize, destination: *mut u8);
}

unsafe fn summary(string: &[u8]) -> Vec<u8> {
    let string_ptr = string.as_ptr();
    let start = align(string_ptr, 16);
    let end = align(string_ptr.add(string.len()), 16);
    let aligned_len: usize = 0;// end.offset_from(start);
    let mut destination: Vec<u8> = Vec::with_capacity(aligned_len / 8);
    let dest_ptr = destination.as_mut_slice().as_mut_ptr();
    process_chars(start, aligned_len, dest_ptr);
    destination
}

/*fn leading_zeros(byte: u8) -> u8 {
    _clz_u8(byte)
}*/

fn to_lower(c: u8) -> u8 {
    if b'A' <= c && c <= b'Z' {
        c + b'a' - b'A'
    } else {
        c
    }
}

fn char_to_value(c: u8) -> u8 {
    if c <= b'9' {
        c - b'0'
    } else {
        to_lower(c) - b'a'
    }
}

fn unichar_from_hex_code(hex_code: &[u8; 4]) -> u16 {
    let shift_amount: usize = 12;
    let mut u: u16 = 0;
    for &c in hex_code {
        let raw: u16 = char_to_value(c) as u16;
        u |= raw << shift_amount;
        shift_amount -= 4;
    }
    u
}

// We want to skip the next slash if that slash is denoting the low part of a unicode surrogate pair
fn FFOProcessEscapedSequence(deletions: &Vec<usize>, string: &str, slash_idx: usize) -> usize {
    let string_len = string.len();
    if slash_idx > string_len - 2 {
        deletions.push(stringLen - slashIdx);
        deletions.push(slashIdx);
        return 0;
    }

    let afterSlash = string[slash_idx + 1];
    if afterSlash == 'u' || afterSlash == 'U' {
        if slash_idx > string_len - 6 {
            deletions.push(stringLen - slashIdx);
            deletions.push(slashIdx);
            return 0;
        }
        let u_chars: &[u16: 2] = [];
        u_chars[0] = unichar_from_hex_code(string + slashIdx + 2);
        uint8_t *targetStart = (uint8_t *)(string + slashIdx);
        memcpy(string + slashIdx, uChars, 2);
        if (UTF16CharIsHighSurrogate(uChars[0]) && slashIdx > stringLen - 12 && string[slashIdx + 6] == '\\' && string[slashIdx + 7] != 'u') {
            uChars[1] = FFOUnicharFromHexCode(string + slashIdx + 8);
            ConvertUTF16toUTF8((const unichar **)&uChars, uChars + 2, &targetStart, targetStart + 4, 0);
            FFOPushToArray(deletions, slashIdx + 4);
            FFOPushToArray(deletions, (6 - 2) * 2);
            return 12;
        } else {
            ConvertUTF16toUTF8((const unichar **)&uChars, uChars + 1, &targetStart, targetStart + 2, 0);
            FFOPushToArray(deletions, slashIdx + 2);
            FFOPushToArray(deletions, 6 - 2);
            return 6;
        }
    }

    FFOPushToArray(deletions, slashIdx + 1);
    FFOPushToArray(deletions, 1);
    string[slashIdx] = FFOEscapeCharForChar(string[slashIdx + 1]);
    return 2;
}

pub fn parse(string: &[u8], callbacks: &Callbacks) {
    let string_ptr = string.as_ptr();
    let dest = unsafe { summary(string) };
    let dest_len = dest.len();
    let mut in_dict = false;
    let mut deletions: Vec<u8> = Vec::new();
    let mut idx: usize = 0;
    let mut next_str_is_a_key = false;
    let len = string.len();
    let quote: u8 = '"' as u8;
    while idx < len {
        match string[idx] {
            quote => {
                let start_idx: usize = idx + 1;
                let dest_idx: usize = start_idx >> 3;
                let offset: usize = start_idx & 0x7;
                let b: u8 = dest[dest_idx] << offset;
                let mut special_idx = 0;
                // todo: separate list for strings?
                let mut hit_end = false;
                while dest_idx < dest_len {
                    while b != 0 {
                        // if __clz is slow, use a lookup table instead
                        let next: usize = (b.leading_zeros() - 24 + 1) as usize;
                        offset += next;
                        b = b << next;
                        // Offset could be 8, so use "+" and not "|"
                        special_idx = ((dest_idx << 3) + offset) - 1;
                        let c = string[special_idx];
                        if c == '\"' as u8 {
                            hit_end = true;
                            break;
                        } else if c == '\\' as u8 {
                            let extraOffset: usize = -1 + process_escaped_sequence(deletions, string, length, special_idx);
                            b = b << extraOffset;
                            offset += extraOffset;
                            // Handles overflow
                            if offset >= 8 {
                                dest_idx += offset >> 3;
                                offset = offset & 0x7;
                                b = dest[dest_idx] << offset;
                            }
                        }
                    }
                    if hit_end {
                        break;
                    }
                    offset = 0;
                    dest_idx += 1;
                    b = dest[dest_idx];
                }
                idx = special_idx;
                if (deletions->length > 0) {
                    FFOPerformDeletions(string, start_idx, idx, deletions, copy_buffer);
                    deletions->length = 0;
                } else {
                    string[idx] = '\0';
                }
                // printf("%s\n", string + startIdx);
                // callbacks->string(string + start_idx);
            }
        }
    }
    // string
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
