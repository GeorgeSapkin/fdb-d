module fdb.tuple.tupletype;

import
    std.exception,
    std.variant;

alias Part = Algebraic!(long, string);

enum TupleType : ubyte {
    /**
     * Null/Empty/Void
     */
    Nil             = 0,

    /**
     * ASCII String
     */
    Bytes           = 1,

    /**
     * UTF-8 String
     */
    Utf8            = 2,

    /**
     * Nested tuple [DRAFT]
     */
    TupleStart      = 3,

    /**
     * End of a nested tuple [DRAFT]
     */
    TupleEnd        = 4,

    IntNeg8         = 12,
    IntNeg7         = 13,
    IntNeg6         = 14,
    IntNeg5         = 15,
    IntNeg4         = 16,
    IntNeg3         = 17,
    IntNeg2         = 18,
    IntNeg1         = 19,

    /**
     * Base value for integer types (20 +/- n)
     */
    IntBase         = 20,
    IntZero         = 20,

    IntPos1         = 21,
    IntPos2         = 22,
    IntPos3         = 23,
    IntPos4         = 24,
    IntPos5         = 25,
    IntPos6         = 26,
    IntPos7         = 27,
    IntPos8         = 28,

    /**
     * RFC4122 UUID (128 bits) [DRAFT]
     */
    Guid            = 48,

    /**
     * Standard prefix of the Directory Layer
     */
    AliasDirectory  = 254,

    /**
     * Standard prefix of the System keys, or frequent suffix with key ranges
     */
    AliasSystem     = 255
}

private immutable ulong[] tupleTypeSize = [
    /* TupleType.IntNeg8 : */ 8,
    /* TupleType.IntNeg7 : */ 7,
    /* TupleType.IntNeg6 : */ 6,
    /* TupleType.IntNeg5 : */ 5,
    /* TupleType.IntNeg4 : */ 4,
    /* TupleType.IntNeg3 : */ 3,
    /* TupleType.IntNeg2 : */ 2,
    /* TupleType.IntNeg1 : */ 1,

    /* TupleType.IntZero : */ 0,

    /* TupleType.IntPos1 : */ 1,
    /* TupleType.IntPos2 : */ 2,
    /* TupleType.IntPos3 : */ 3,
    /* TupleType.IntPos4 : */ 4,
    /* TupleType.IntPos5 : */ 5,
    /* TupleType.IntPos6 : */ 6,
    /* TupleType.IntPos7 : */ 7,
    /* TupleType.IntPos8 : */ 8,
];

auto FDBsizeof(const TupleType type) pure
{
    enforce(type.isFDBIntegral);
    return tupleTypeSize[type - TupleType.IntNeg8];
}

bool isFDBIntegral(const TupleType type) pure
{
    return type >= TupleType.IntNeg8 && type <= TupleType.IntPos8;
}
