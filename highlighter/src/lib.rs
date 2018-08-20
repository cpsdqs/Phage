use std::os::raw::*;
use std::ffi::CStr;
use syntect::parsing::{SyntaxSet, ParseState, ScopeStack};
use syntect::highlighting::{
    Theme, ThemeSet, Highlighter, HighlightState, HighlightIterator, Color, FontStyle
};
use std::mem;

extern crate syntect;

const CACHE_INTERVAL: usize = 8;

struct SyntaxHighlighter {
    syntax_set: SyntaxSet,
    cache: Vec<(ParseState, HighlightState)>,
    theme_set: ThemeSet,
    dark_mode: bool,
}

impl SyntaxHighlighter {
    fn theme(&self) -> &Theme {
        match self.dark_mode {
            true => &self.theme_set.themes["Dash"],
            false => &self.theme_set.themes["Dash (light)"],
        }
    }
}

fn str_from_cstr(cstr: *const c_char) -> &'static str {
    unsafe { CStr::from_ptr(cstr) }.to_str().unwrap_or("")
}

#[no_mangle]
pub extern "C" fn new_highlighter(folder: *const c_char) -> *mut c_void {
    let folder = str_from_cstr(folder);
    let mut syntax_set = match SyntaxSet::load_from_folder(folder) {
        Ok(x) => x,
        Err(err) => {
            eprintln!("{:?}", err);
            return 0 as *mut _
        }
    };
    syntax_set.link_syntaxes();
    let theme_set = ThemeSet::load_from_folder(folder).unwrap();

    Box::into_raw(Box::new(SyntaxHighlighter {
        syntax_set,
        cache: Vec::new(),
        theme_set,
        dark_mode: false,
    })) as *mut _
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct StyleColor {
    r: f64,
    g: f64,
    b: f64,
    a: f64,
}

impl From<Color> for StyleColor {
    fn from(col: Color) -> StyleColor {
        StyleColor {
            r: col.r as f64 / 255.,
            g: col.g as f64 / 255.,
            b: col.b as f64 / 255.,
            a: col.a as f64 / 255.,
        }
    }
}

#[repr(C)]
pub struct StyleItem {
    line: u64,
    pos: u64,
    len: u64,
    fg: StyleColor,
    bg: StyleColor,
    bold: bool,
    underline: bool,
    italic: bool,
}

#[repr(C)]
pub struct StyleItemList {
    count: u64,
    items: *mut StyleItem,
}

#[no_mangle]
pub extern "C" fn highlight_range(highlighter: *mut c_void, text: *const c_char, line: u64, line_count: u64, total_lines: u64) -> StyleItemList {
    let highlighter: &mut SyntaxHighlighter = unsafe { &mut *(highlighter as *mut _) };
    let text = str_from_cstr(text);
    let line = line as usize;
    let line_count = line_count as usize;
    let total_lines = total_lines as usize;

    let last_valid_cache = (line - 1) / CACHE_INTERVAL;
    if highlighter.cache.len() > last_valid_cache {
        highlighter.cache.drain((last_valid_cache + 1)..).for_each(drop);
    }
    let last_cached_line = highlighter.cache.len().saturating_sub(1) * CACHE_INTERVAL;
    let start_line = if last_cached_line == 0 {
        0
    } else {
        last_cached_line + 1
    };

    let mut end_line = line + line_count;
    end_line += CACHE_INTERVAL - (end_line % CACHE_INTERVAL);
    if end_line > total_lines {
        end_line = total_lines;
    }

    let mut line_iter = text.lines();
    for _ in 0..start_line {
        line_iter.next();
    }

    let mut styles = Vec::new();

    let borrowck_hack: &mut SyntaxHighlighter = unsafe { &mut *(highlighter as *mut _) };
    let syn_hl = Highlighter::new(borrowck_hack.theme());

    let syntax_defn = highlighter.syntax_set.find_syntax_by_extension("js").unwrap();
    let (mut parse_state, mut hl_state) = match highlighter.cache.get(highlighter.cache.len().saturating_sub(1)) {
        Some(cached) => cached.clone(),
        None => (
            ParseState::new(syntax_defn),
            HighlightState::new(&syn_hl, ScopeStack::default()),
        )
    };

    for ln in start_line..end_line {
        let line_content = match line_iter.next() {
            Some(x) => if x.len() > 500 {
                &x[..500]
            } else {
                x
            },
            None => {
                let list = StyleItemList {
                    count: styles.len() as u64,
                    items: styles.as_mut_ptr(),
                };
                mem::forget(styles);
                return list
            }
        };
        let ops = parse_state.parse_line(line_content);
        {
            let iter = HighlightIterator::new(&mut hl_state, &ops, line_content, &syn_hl);
            let mut index = 0;
            for (item, chunk) in iter {
                styles.push(StyleItem {
                    line: ln as u64,
                    pos: index,
                    len: chunk.len() as u64,
                    fg: item.foreground.into(),
                    bg: item.background.into(),
                    bold: item.font_style.contains(FontStyle::BOLD),
                    underline: item.font_style.contains(FontStyle::UNDERLINE),
                    italic: item.font_style.contains(FontStyle::ITALIC),
                });
                index += chunk.len() as u64;
            }
        }

        if ln == highlighter.cache.len() * CACHE_INTERVAL {
            highlighter.cache.push((parse_state.clone(), hl_state.clone()));
        }
    }

    let list = StyleItemList {
        count: styles.len() as u64,
        items: styles.as_mut_ptr(),
    };
    mem::forget(styles);
    list
}

#[no_mangle]
pub extern "C" fn invalidate_cache(highlighter: *mut c_void) {
    let highlighter: &mut SyntaxHighlighter = unsafe { &mut *(highlighter as *mut _) };
    highlighter.cache.clear();
}

#[no_mangle]
pub extern "C" fn background_color(highlighter: *mut c_void) -> StyleColor {
    let highlighter: &mut SyntaxHighlighter = unsafe { &mut *(highlighter as *mut _) };
    highlighter.theme().settings.background.map(|x| x.into()).unwrap_or_default()
}

#[no_mangle]
pub extern "C" fn set_dark_mode(highlighter: *mut c_void, dark_mode: bool) {
    let highlighter: &mut SyntaxHighlighter = unsafe { &mut *(highlighter as *mut _) };
    if dark_mode != highlighter.dark_mode {
        highlighter.dark_mode = dark_mode;
        highlighter.cache.clear();
    }
}

#[no_mangle]
pub extern "C" fn dealloc_highlighter(highlighter: *mut c_void) {
    unsafe { Box::from_raw(highlighter as *mut SyntaxHighlighter) };
}
