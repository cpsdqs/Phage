//
//  Highlighter.m
//  Phage
//
//  Created by cpsdqs on 2018-08-19.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

#import "Highlighter.h"
#import "libhighlighter.h"

@implementation HLStyleItem
@synthesize line;
@synthesize range;
@synthesize foreground;
@synthesize background;
@synthesize bold;
@synthesize underline;
@synthesize italic;
@synthesize charRange;
@end

@implementation Highlighter {
    void* _highlighter;
}

- (instancetype)initWithFolder:(NSString *)path {
    self = [super init];
    _highlighter = new_highlighter([path cStringUsingEncoding:NSUTF8StringEncoding]);
    return self;
}

- (NSArray<HLStyleItem*> *)highlight:(NSString *)text atLine:(NSUInteger)startLine lineCount:(NSUInteger)lineCount totalLines:(NSUInteger)totalLines {
    struct StyleItemList list = highlight_range(_highlighter, [text cStringUsingEncoding:NSUTF8StringEncoding], startLine, lineCount, totalLines);

    NSMutableArray* styleItems = [[NSMutableArray alloc] init];

    for (int i = 0; i < list.count; i++) {
        struct StyleItem item = list.items[i];
        struct StyleColor fg = item.fg;
        struct StyleColor bg = item.bg;
        HLStyleItem* styleItem = [HLStyleItem alloc];

        styleItem.line = item.line;
        styleItem.range = NSMakeRange(item.pos, item.len);
        styleItem.foreground = [NSColor colorWithSRGBRed:fg.r green:fg.g blue:fg.b alpha:fg.a];
        styleItem.background = [NSColor colorWithSRGBRed:bg.r green:bg.g blue:bg.b alpha:bg.a];
        styleItem.bold = item.bold;
        styleItem.underline = item.underline;
        styleItem.italic = item.italic;

        [styleItems addObject:styleItem];
    }

    return styleItems;
}

- (void)invalidateCache {
    invalidate_cache(_highlighter);
}

- (NSColor *)backgroundColor {
    struct StyleColor bg = background_color(_highlighter);
    return [NSColor colorWithSRGBRed:bg.r green:bg.g blue:bg.b alpha:bg.a];
}

- (void)setDarkMode:(BOOL)darkMode {
    set_dark_mode(_highlighter, darkMode);
}

- (void)dealloc {
    dealloc_highlighter(_highlighter);
}

@end
