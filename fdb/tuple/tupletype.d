module fdb.tuple.tupletype;

import
    std.exception;

enum TupleType : ubyte {
    /**
     * Null/Empty/Void
     */
    Nil             = 0,

    /**
     * ASCII String
     */
    Bytes           = 1,

    /// <summary>UTF-8 String</summary>
    Utf8            = 2,

    /// <summary>Nested tuple [DRAFT]</summary>
    TupleStart      = 3,

    /// <summary>End of a nested tuple [DRAFT]</summary>
    TupleEnd        = 4,

    IntNeg8         = 12,
    IntNeg7         = 13,
    IntNeg6         = 14,
    IntNeg5         = 15,
    IntNeg4         = 16,
    IntNeg3         = 17,
    IntNeg2         = 18,
    IntNeg1         = 19,

    /// <summary>Base value for integer types (20 +/- n)</summary>
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

    /// <summary>RFC4122 UUID (128 bits) [DRAFT]</summary>
    Guid            = 48,

    /// <summary>Standard prefix of the Directory Layer</summary>
    /// <remarks>This is not a part of the tuple encoding itself, but helps the tuple decoder pretty-print tuples that would otherwise be unparsable.</remarks>
    AliasDirectory  = 254,

    /// <summary>Standard prefix of the System keys, or frequent suffix with key ranges</summary>
    /// <remarks>This is not a part of the tuple encoding itself, but helps the tuple decoder pretty-print End keys from ranges, that would otherwise be unparsable.</remarks>
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