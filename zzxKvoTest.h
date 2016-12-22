//
//  zzxKvoTest.h
//  USCDemo
//
//  Created by 张忠旭 on 2016/12/22.
//  Copyright © 2016年 usc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+ZZXKVO.h"

@interface zzxKvoTest : NSObject
@property (nonatomic, strong) NSString* name;
+ (id)getInstance;
@end
