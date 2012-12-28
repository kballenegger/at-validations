//
//  ATValidations.h
//  Azure Talon
//
//  Created by Kenneth Ballenegger on 12/10/12.
//
//

#import <Foundation/Foundation.h>




@class ATVPredicate;

extern NSString *const kATVPredicateError;


BOOL ATVAssert(BOOL assertion, NSString *errorMessage, NSError **error);



ATVPredicate *ATVArrayOf(ATVPredicate *predicate);
ATVPredicate *ATVDictionary(NSDictionary *mask, BOOL allowExtra);

ATVPredicate *ATVNumber(void);
ATVPredicate *ATVString(void);
ATVPredicate *ATVInstanceOf(Class klass);

ATVPredicate *ATVMatchesBlock(BOOL(^)(id object, NSError **error));

#define ATVUnion(...) ATVUnionA(@[ __VA_ARGS__ ])
ATVPredicate *ATVUnionA(id<NSFastEnumeration> predicates);
#define ATVOption(...) ATVOptionA(@[ __VA_ARGS__ ])
ATVPredicate *ATVOptionA(id<NSFastEnumeration> predicates);

#define ATVInSet(...) ATVInSetA(@[ __VA_ARGS__ ])
ATVPredicate *ATVInSetA(id<NSFastEnumeration> values);

ATVPredicate *ATVEqual(id value);
ATVPredicate *ATVExists(void);
ATVPredicate *ATVNull(void);
ATVPredicate *ATVNullOr(ATVPredicate *predicate);


@interface NSObject (ATValidations)
- (BOOL)matchesATVPredicate:(ATVPredicate *)predicate error:(NSError **)error;
@end

@interface NSDictionary (ATValidations)
- (BOOL)matchesMask:(NSDictionary *)mask allowExtraKeys:(BOOL)allowExtra error:(NSError **)error;
@end
