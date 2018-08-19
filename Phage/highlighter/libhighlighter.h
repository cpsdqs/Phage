//
//  libhighlighter.h
//  Phage
//
//  Created by cpsdqs on 2018-08-19.
//  Copyright © 2018 cpsdqs. All rights reserved.
//
// See /highlighter for rust source

#ifndef libhighlighter_h
#define libhighlighter_h

struct StyleColor {
    double r;
    double g;
    double b;
    double a;
};

struct StyleItem {
    uint64 line;
    uint64 pos;
    uint64 len;
    struct StyleColor fg;
    struct StyleColor bg;
    bool bold;
    bool underline;
    bool italic;
};

struct StyleItemList {
    uint64 count;
    struct StyleItem* items;
};

void* new_highlighter(const char* folder);
struct StyleItemList highlight_range(void* highlighter, const char* text, const uint64 line, const uint64 line_count, const uint64 total_lines);
void invalidate_cache(void* highlighter);
void dealloc_highlighter(void* highlighter);

#endif /* libhighlighter_h */
