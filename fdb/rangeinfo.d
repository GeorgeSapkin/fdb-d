module fdb.rangeinfo;

import
    fdb.fdb_c,
    fdb.fdb_c_options;

struct Selector
{
    const Key     key;
    const bool    orEqual;
    const int     offset;
}

struct RangeInfo
{
    const Selector      start;
    const Selector      end;
    const int           limit;
    const StreamingMode mode;
    int                 iteration;
    const bool          snapshot;
    const bool          reverse;
}

/*
 * #define FDB_KEYSEL_LAST_LESS_THAN(k, l) k, l, 0, 0
 * #define FDB_KEYSEL_LAST_LESS_OR_EQUAL(k, l) k, l, 1, 0
 * #define FDB_KEYSEL_FIRST_GREATER_THAN(k, l) k, l, 1, 1
 * #define FDB_KEYSEL_FIRST_GREATER_OR_EQUAL(k, l) k, l, 0, 1
 */

auto lastLessThan(const Key key)
{
    return Selector(key, false, 0);
}

auto lastLessOrEqual(const Key key)
{
    return Selector(key, true, 0);
}

auto firstGreaterThan(const Key key)
{
    return Selector(key, true, 1);
}

auto firstGreaterOrEqual(const Key key)
{
    return Selector(key, false, 1);
}