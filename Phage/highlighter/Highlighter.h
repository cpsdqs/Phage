//
//  Highlighter.h
//  Phage
//
//  Created by cpsdqs on 2018-08-19.
//  Copyright © 2018 cpsdqs. All rights reserved.
//

@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface HLStyleItem : NSObject
@property (nonatomic) NSUInteger line;
@property (nonatomic) NSRange range;
@property (nonatomic) NSColor* foreground;
@property (nonatomic) NSColor* background;
@property (nonatomic) BOOL bold;
@property (nonatomic) BOOL underline;
@property (nonatomic) BOOL italic;
@end

@interface Highlighter : NSObject

- (instancetype)initWithFolder:(NSString *)path;
- (NSArray<HLStyleItem*> *)highlight:(NSString *)text atLine:(NSUInteger)startLine lineCount:(NSUInteger)lineCount totalLines:(NSUInteger)totalLines;
- (void)invalidateCache;

@end

NS_ASSUME_NONNULL_END
