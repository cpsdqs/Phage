//
//  Glob.m
//  PhageExtension
//
//  Created by cpsd on 2018-07-20.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

#import "libglob.h"
#import "glob.h"

/**
 Converts a glob string to a regex string. This is a wrapper for libglob.dylib (Rust FFI). Errors will be printed to the console (TODO: maybe don’t).

 @param glob the glob
 @return the glob in regex form, or nil if an error occured.
 */
NSString* globToRegex(NSString* glob) {
    const char* cString = [glob cStringUsingEncoding:NSUTF8StringEncoding];
    char* error = "";
    const char* result = glob_to_regex(cString, &error);
    if (result == 0) {
        NSLog(@"libglob error: %@", [[NSString alloc] initWithCString:error encoding:NSUTF8StringEncoding]);
        return nil;
    }
    return [[NSString alloc] initWithCString:result encoding:NSUTF8StringEncoding];
}
