//
//  NSObject+ZZXKVO.m
//  USCDemo
//
//  Created by 张忠旭 on 2016/12/22.
//  Copyright © 2016年 usc. All rights reserved.
//

#import "NSObject+ZZXKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

/*
 新建类名的前缀
 */
NSString *const ZZXKVOClassPreFix = @"ZZXKVOClassPreFix_";
/*
 动态添加数组的标识
 */
NSString *const ZZXKVOAssociatedObservers = @"ZZXKVOAssociatedObservers";

#pragma mark - ZZXObservationInfo
/*
    添加的observer信息，存储在数组里
 */
@interface ZZXObservationInfo : NSObject
@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) ZZXObservingBlock block;
@end

@implementation ZZXObservationInfo
- (instancetype)initWithObserver:(NSObject *)observer Key:(NSString *)key block:(ZZXObservingBlock)block
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}
@end

@implementation NSObject (ZZXKVO)

#pragma mark - Helpers
/*
 通过setter的函数名，获取属性的名字，转换时要去掉“set”,":",并小写名字的第一个字母
 */
static NSString * getterForSetter(NSString *setter)
{
    if (setter.length <= 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    // lower case the first letter
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    return key;

}

/*
 通过属性名，获取setter方法名，setter方法第一个字母大写
 */
static NSString * setterForGetter(NSString *getter)
{
    if (getter.length <= 0) {
        return nil;
    }
    
    // upper case the first letter
    NSString *firstLetter = [[getter substringToIndex:1] uppercaseString];
    NSString *remainingLetters = [getter substringFromIndex:1];
    
    // add 'set' at the begining and ':' at the end
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", firstLetter, remainingLetters];
    
    return setter;

}

#pragma mark - Overridden Methods
/*
 新建类自己的setter方法
 */
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterForSetter(setterName);
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    id oldValue = [self valueForKey:getterName];
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    // cast our pointer so the compiler won't complain
    
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // call super's setter, which is original class's setter method
    //给父类发送setter，通过断点可以看到执行新执行的是新建类的setter 然后是父类的setter
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    // look up observers and call the blocks
    //添加数组用于保存各个添加进来的观察者
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(ZZXKVOAssociatedObservers));
    for (ZZXObservationInfo *each in observers) {
        if ([each.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                each.block(self, getterName, oldValue, newValue);
            });
        }
    }

}

static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

- (void)ZZX_addObserver:(NSObject *)observer forkey:(NSString *)key withBlock:(ZZXObservingBlock)block
{
    // Step 1: Throw exception if its class or superclasses doesn't implement the setter
    SEL setterSelector = NSSelectorFromString(setterForGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    //如果没有setter，比如属性是只读
    if (!setterMethod) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    Class clazz = object_getClass(self);
    NSString *clazzName = NSStringFromClass(clazz);
    
    // if not an KVO class yet
    //第一次添加观察者时，还没有创建该类，第二次添加观察者时就不用再创建了
    if (![clazzName hasPrefix:ZZXKVOClassPreFix]) {
        clazz = [self makeKvoClassWithOriginalClassName:clazzName];
        //设置self类型为新建的子类，这样设置属性的值时就会调用新建的子类的setter
        object_setClass(self, clazz);
    }
    
    // add our kvo setter if this class (not superclasses) doesn't implement the setter?
    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSelector, (IMP)kvo_setter, types);
    }
    //开始回调value给各个观察者
    ZZXObservationInfo *info = [[ZZXObservationInfo alloc] initWithObserver:observer Key:key block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(ZZXKVOAssociatedObservers));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(ZZXKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}
- (void)ZZX_removeObserver:(NSObject *)observer forKey:(NSString *)key
{
    NSMutableArray* observers = objc_getAssociatedObject(self, (__bridge const void *)(ZZXKVOAssociatedObservers));
    
    ZZXObservationInfo *infoToRemove;
    for (ZZXObservationInfo* info in observers) {
        if (info.observer == observer && [info.key isEqual:key]) {
            infoToRemove = info;
            break;
        }
    }
    
    [observers removeObject:infoToRemove];

}

- (Class)makeKvoClassWithOriginalClassName:(NSString *)originalClazzName
{
    //originalClazzName父类名字   kvoClazzName子类名字
    NSString *kvoClazzName = [ZZXKVOClassPreFix stringByAppendingString:originalClazzName];
    Class clazz = NSClassFromString(kvoClazzName);
    if (clazz) {
        return clazz;
    }
    // class doesn't exist yet, make it
    Class originalClazz = object_getClass(self);
    //新建类
    Class kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
    
    // grab class method's signature so we can borrow it
    Method clazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, types);
    
    //这个一定要在新建方法之后再执行，执行之后，类不能再添加方法了
    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}

- (BOOL)hasSelector:(SEL)selector
{
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    Method* methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;

}

@end
