//
//  NSObject+ZZXKVO.h
//  USCDemo
//
//  Created by 张忠旭 on 2016/12/22.
//  Copyright © 2016年 usc. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void (^ZZXObservingBlock) (id observedObject, NSString *observedKey, id oldValue, id newValue);
@interface NSObject (ZZXKVO)
/*
 添加自己的 addobserver
 取代NSObject原有的 [self addObserver:(nonnull NSObject *) forKeyPath:(nonnull NSString *) options:(NSKeyValueObservingOptions) context:      (nullable void *)];
 
 PGObservingBlock block回调
 取代 NSObject原有的- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id>  *)change context:(void *)context
 */
- (void)ZZX_addObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(ZZXObservingBlock)block;
- (void)ZZX_removeObserver:(NSObject *)observer forKey:(NSString *)key;
@end
