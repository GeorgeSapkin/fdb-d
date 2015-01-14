module fdb.rangeinfo;

import
    std.array,
    std.exception;

import
    fdb.fdb_c,
    fdb.fdb_c_options;

struct Selector
{
    Key  key;
    bool orEqual;
    int  offset;
}

struct RangeInfo
{
    Selector      begin;
    Selector      end;
    int           limit;
    StreamingMode mode;
    int           iteration;
    bool          reverse;
}

/*
 * #define FDB_KEYSEL_LAST_LESS_THAN(k, l) k, l, 0, 0
 * #define FDB_KEYSEL_LAST_LESS_OR_EQUAL(k, l) k, l, 1, 0
 * #define FDB_KEYSEL_FIRST_GREATER_THAN(k, l) k, l, 1, 1
 * #define FDB_KEYSEL_FIRST_GREATER_OR_EQUAL(k, l) k, l, 0, 1
 */

auto lastLessThan(in Key key)
{
    return Selector(key.dup, false, 0);
}

auto lastLessOrEqual(in Key key)
{
    return Selector(key.dup, true, 0);
}

auto firstGreaterThan(in Key key)
{
    return Selector(key.dup, true, 1);
}

auto firstGreaterOrEqual(in Key key)
{
    return Selector(key.dup, false, 1);
}

auto createRangeInfo(
    in Key           begin,
    in Key           end       = null,
    in int           limit     = 0,
    in StreamingMode mode      = StreamingMode.ITERATOR,
    in bool          reverse   = false,
    in int           iteration = 1)
{
    auto sanBegin = sanitizeKey(begin, [ 0x00 ]);
    auto sanEnd   = sanitizeKey(end, sanBegin.getEndPrefix);

    auto beginSel = sanBegin.firstGreaterOrEqual;
    auto endSel   = sanEnd.firstGreaterOrEqual;

    auto rangeInfo = RangeInfo(
            beginSel, endSel, limit, mode, iteration, reverse);
    return rangeInfo;
}

auto createRangeInfoInclusive(
    in Key           begin,
    in Key           end       = null,
    in int           limit     = 0,
    in StreamingMode mode      = StreamingMode.ITERATOR,
    in bool          reverse   = false,
    in int           iteration = 1)
{
    auto sanBegin = sanitizeKey(begin, [ 0x00 ]);
    auto sanEnd   = sanitizeKey(end, sanBegin.getEndPrefix);

    auto beginSel = sanBegin.firstGreaterOrEqual;
    auto endSel   = sanEnd.firstGreaterThan;

    auto rangeInfo = RangeInfo(
            beginSel, endSel, limit, mode, iteration, reverse);
    return rangeInfo;
}

auto createRangeInfo(
    Selector         beginSel,
    Selector         endSel,
    in int           limit     = 0,
    in StreamingMode mode      = StreamingMode.ITERATOR,
    in bool          reverse   = false,
    in int           iteration = 1)
{
    auto rangeInfo = RangeInfo(
            beginSel, endSel, limit, mode, iteration, reverse);
    return rangeInfo;
}

alias range          = createRangeInfo;
alias rangeInclusive = createRangeInfoInclusive;

auto sanitizeKey(in Key key, lazy Key fallback) pure
{
    if (key is null || key.empty)
        return fallback;
    return key;
}

auto getEndPrefix(in Key prefix) pure
in
{
    enforce(prefix !is null);
    enforce(prefix.length > 0);
}
body
{
    ulong i = prefix.length;
    if (i == 1) return [ cast(ubyte) 0xff ];

    do --i;
    while (i != 0 && prefix[i] == 0xff);

    enforce(prefix[i] != 0xff, "All prefix bytes cannot equal 0xff");

    auto endPrefix = prefix[0 .. i + 1].dup;
    ++endPrefix[i];
    return endPrefix;
}
