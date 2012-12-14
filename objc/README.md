This is the awesomest piece of Obj-C code I've written today :).

This lets you expressively describe objects and perform validation on them. This is especially useful to ensure that API responses match an expected format. It lets you perform validation on the format just once, and if passing, assume the data is valid.

Validations are centered around `ATVPredicate` objects. A predicate describes whether a value is valid or not (through a block which validates objects).

The most common use case of validations will be to validate a `NSDictionary`, so let's start with an example of how that might work:

```objc
NSDictionary *dict;
NSError *error = nil;
if (![dict matchesMask:@{
            @"status": ATVEqual(@200),
            @"message": ATVString(),
            @"items": ATVArrayOf(ATVDictionary(@{
                @"_id": ATVString(),
                @"type": ATVInSet(@"iap", @"currency", nil),
                @"odd_number": ATVUnion(
                    ATVNumber(),
                    ATVMatchesBlock(^(NSNumber *n, NSError **e) {
                        return ATVAssert((n.intValue % 2) != 0,
                            @"must be an odd number", e);
                    }), nil)
            }, YES)),
        } allowExtraKeys:YES error:&error]) {
    NSLog(@"failure!\n%@", error);
}
```

This will validate `dict` against a mask specifying that:

- `dict.status` must be `@200`
- `dict.message` must be a string
- `dict.items` must be an array of dictionaries, which must match this mask:
  - `item._id` must be a string
  - `item.type` must be either `iap` or `currency`
  - `item.odd_number` must fulfill both of these predicates:
      - it must be a number
      - it must pass the block predicate passed

That last one shows the power of building custom predicates. You simply provide a block which takes any `id object` as first parameter and return a BOOL to validate the object.

`ATVAssert` is a convenience function which will simply return its first (`BOOL`) argument, but will also create an error in the pointer passed with the provided error string, when the boolean is false.

Here is the full list of predicates:

```objc
ATVPredicate *ATVArrayOf(ATVPredicate *predicate);
ATVPredicate *ATVDictionary(NSDictionary *mask, BOOL allowExtra);

ATVPredicate *ATVNumber(void);
ATVPredicate *ATVString(void);
ATVPredicate *ATVInstanceOf(Class klass);

ATVPredicate *ATVMatchesBlock(BOOL(^)(id object, NSError **error));

ATVPredicate *ATVUnion(ATVPredicate *first, ...) NS_REQUIRES_NIL_TERMINATION;
ATVPredicate *ATVOption(ATVPredicate *first, ...) NS_REQUIRES_NIL_TERMINATION;

ATVPredicate *ATVInSet(id first, ...) NS_REQUIRES_NIL_TERMINATION;

ATVPredicate *ATVEqual(id value);
ATVPredicate *ATVExists(void);
ATVPredicate *ATVNull(void);
```

You can also easily write your own. For example:

```objc
ATVPredicate *CBAPIPredicateTwohundreds(void) {
    static ATVPredicate *instance = nil;
    if (!instance) {
        instance = [ATVUnion(ATVNumber(), ATVMatchesBlock(^BOOL(NSNumber *n, NSError **e) {
            return ATVAssert(n.intValue >= 200 && n.intValue < 300, @"must be a valid status code (>=200 && <300)", e);
        }), nil) retain];
    }
    return instance;
}
```

### Implementation

All predicate objects are backed by a block which returns a boolean for validity, and takes an object as its first argument, and a double-pointer to `NSError` as second argument. The `ATVPredicate` class itself is just a wrapper for that block.

```objc
BOOL(^myPredicateBlock)(id object, NSError **error)
```


/review @fannan @mkinsella 