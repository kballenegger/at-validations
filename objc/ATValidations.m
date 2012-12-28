//
//  ATValidations.m
//  Azure Talon
//
//  Created by Kenneth Ballenegger on 12/10/12.
//
//

#import "ATValidations.h"


@interface ATVPredicate : NSObject
@property (copy) BOOL(^block)(id object, NSError **error);
@end

NSString *const kATVPredicateError = @"ATVPredicateError";





BOOL ATVAssert(BOOL assertion, NSString *errorMessage, NSError **error) {
    if (!assertion && error) {
        *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{@"error": errorMessage}];
    }
    return assertion;
}





// matches block is the master definition, all others simply use this definition
ATVPredicate *ATVMatchesBlock(BOOL(^block)(id object, NSError **error)) {
    ATVPredicate *type = [[ATVPredicate alloc] init];
    type.block = block;
    return [type autorelease];
}

ATVPredicate *ATVUnionA(id<NSFastEnumeration> predicates) {

    return ATVMatchesBlock(^BOOL(id object, NSError **error) {

        NSError *failure = nil;
        for (ATVPredicate *predicate in predicates) {
            if (!predicate.block(object, &failure)) {
                if (error) {
                    *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                               @"error": @"union predicate failed",
                               @"failure": failure.userInfo
                               }];
                }
                return NO;
            }
        }
        return YES;
    });
}

ATVPredicate *ATVOptionA(id<NSFastEnumeration> predicates) {
    
    return ATVMatchesBlock(^BOOL(id object, NSError **error) {

        NSMutableArray *failures = [NSMutableArray array];
        for (ATVPredicate *predicate in predicates) {
            NSError *failure = nil;
            if (predicate.block(object, &failure)) {
                return YES;
            } else {
                [failures addObject:failure.userInfo];
            }
        }
        
        if (error) {
            *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                       @"error": @"option predicate failed",
                       @"failures": failures
                       }];
        }
        return NO;
    });
}

ATVPredicate *ATVEqual(id value) {
    return ATVMatchesBlock(^BOOL(id object, NSError **error) {
        return ATVAssert([object isEqual:value], [NSString stringWithFormat:@"must be equal: %@ != %@", object, value], error);
    });
}

ATVPredicate *ATVExists() {
    static ATVPredicate *instance = nil;
    if (!instance) {
        instance = [ATVMatchesBlock(^BOOL(id object, NSError **error) {
            return ATVAssert(object != nil, @"must exist", error);
        }) retain];
    }
    return instance;
}

ATVPredicate *ATVNull() {
    static ATVPredicate *instance = nil;
    if (!instance) {
        instance = [ATVMatchesBlock(^BOOL(id object, NSError **error) {
            return ATVAssert(object == nil, @"must be null", error);
        }) retain];
    }
    return instance;
}

ATVPredicate *ATVNullOr(ATVPredicate *predicate) {
    return ATVOption(ATVNull(), predicate);
}


ATVPredicate *ATVInSetA(id<NSFastEnumeration> values) {

    return ATVMatchesBlock(^BOOL(id object, NSError **error) {
        
        for (id value in values) {
            if ([object isEqual:value]) {
                return YES;
            }
        }
        
        if (error) {
            *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                       @"error": @"must be in set of values provided",
                       @"options": values
                       }];
        }
        return NO;
    });
}

ATVPredicate *ATVArrayOf(ATVPredicate *predicate) {
    return ATVMatchesBlock(^BOOL(id object, NSError **error) {
        if (![object isKindOfClass:[NSArray class]]) {
            if (error) {
                *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                                @"error": @"expecting array"
                           }];
            }
            return NO;
        }
        __block BOOL valid = YES;
        NSMutableDictionary *errors = [NSMutableDictionary dictionary];
        [(NSArray *)object enumerateObjectsUsingBlock:^(id member, NSUInteger idx, BOOL *stop) {
            NSError *error;
            BOOL memberValid = predicate.block(member, &error);
            if (!memberValid && error) {
                errors[@(idx)] = error.userInfo;
            }
            valid *= memberValid;
        }];
        
        if (error && !valid) {
            *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                           @"error": @"array children invalid",
                           @"failures": errors
                       }];
        }
        
        return valid;
    });
}

ATVPredicate *ATVDictionary(NSDictionary *mask, BOOL allowExtra) {
    return ATVMatchesBlock(^BOOL(id object, NSError **error) {
        if (![object isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                               @"error": @"expecting dictionary"
                           }];
            }
            return NO;
        }
        __block BOOL valid = YES;
        NSMutableDictionary *errors = [NSMutableDictionary dictionary];
        void(^eachObject)(id key, id member, BOOL *stop) = ^(id key, id member, BOOL *stop) {
            
            ATVPredicate *predicate = mask[key];
            if (predicate) assert([predicate isKindOfClass:[ATVPredicate class]]);
            
            BOOL memberValid = YES;
            if (!allowExtra && !predicate) {
                memberValid = NO;
                errors[key] = @{@"error" : @"extra key not allowed", @"key": key};
            } else if (predicate) {
                NSError *error;
                memberValid = predicate.block(member, &error);
                if (!memberValid && error) {
                    errors[key] = error.userInfo;
                }
            }
            valid *= memberValid;
            
        };
        
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:eachObject];
        [(NSDictionary *)mask enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if (!((NSDictionary *)object)[key]) {
                eachObject(key, nil, nil);
            }
        }];
        
        if (error && !valid) {
            *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                           @"error": @"dictionary children invalid",
                           @"failures": errors
                       }];
        }
        
        return valid;
    });
}

ATVPredicate *ATVNumber(void) {
    static ATVPredicate *instance = nil;
    if (!instance)
        instance = [ATVInstanceOf([NSNumber class]) retain];
    return instance;
}

ATVPredicate *ATVString(void) {
    static ATVPredicate *instance = nil;
    if (!instance)
        instance = [ATVInstanceOf([NSString class]) retain];
    return instance;
}

ATVPredicate *ATVInstanceOf(Class klass) {
    return ATVMatchesBlock(^BOOL(id object, NSError **error) {
        if (![object isKindOfClass:klass]) {
            if (error) {
                *error = [NSError errorWithDomain:kATVPredicateError code:1 userInfo:@{
                               @"error": [NSString stringWithFormat:@"expecting instance of class %@", NSStringFromClass(klass)]
                           }];
            }
            return NO;
        } else {
            return YES;
        }
    });

}



@implementation ATVPredicate
- (void)dealloc {
    self.block = nil;
    [super dealloc];
}
@end


@implementation NSObject (ATValidations)

- (BOOL)matchesATVPredicate:(ATVPredicate *)type error:(NSError **)error {
    return type.block(self, error);
}

@end

@implementation NSDictionary (ATValidations)

- (BOOL)matchesMask:(NSDictionary *)mask allowExtraKeys:(BOOL)allowExtra error:(NSError **)error {
    return [self matchesATVPredicate:ATVDictionary(mask, allowExtra) error:error];
}

@end
