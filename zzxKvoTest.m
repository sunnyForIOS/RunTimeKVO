//
//  zzxKvoTest.m
//  USCDemo
//
//  Created by 张忠旭 on 2016/12/22.
//  Copyright © 2016年 usc. All rights reserved.
//

#import "zzxKvoTest.h"

@implementation zzxKvoTest
+ (id)getInstance
{
    static zzxKvoTest *sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[zzxKvoTest alloc] init];
    });
    return sharedManager;
}

- (void)setName:(NSString *)name
{
    NSLog(@"hehe");
}
@end
