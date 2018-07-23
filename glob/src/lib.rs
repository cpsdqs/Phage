use std::os::raw::*;
use std::ffi::{CStr, CString};
use globset::Glob;

extern crate globset;

#[no_mangle]
pub extern "C" fn glob_to_regex(pattern: *const c_char, error: *mut *mut c_char) -> *mut c_char {
    let pattern = unsafe { CStr::from_ptr(pattern) };
    let pattern = match pattern.to_str() {
        Ok(res) => res,
        Err(err) => {
            unsafe { *error = CString::new(format!("{:?}", err)).unwrap().into_raw() };
            return 0 as *mut c_char
        }
    };
    let glob = match Glob::new(pattern) {
        Ok(glob) => glob,
        Err(err) => {
            unsafe { *error = CString::new(format!("{:?}", err)).unwrap().into_raw() };
            return 0 as *mut c_char
        }
    };
    match CString::new(glob.regex()) {
        Ok(res) => res,
        Err(err) => {
            unsafe { *error = CString::new(format!("{:?}", err)).unwrap().into_raw() };
            return 0 as *mut c_char
        }
    }.into_raw()
}
