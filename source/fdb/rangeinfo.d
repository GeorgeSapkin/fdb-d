module fdb.rangeinfo;

import
    fdb.fdb_c,
    fdb.fdb_c_options;

struct Selector
{
    Key     key;
    bool    orEqual;
    int     offset;
}

struct RangeInfo
{
    Selector        begin;
    Selector        end;
    int             limit;
    StreamingMode   mode;
    int             iteration;
    bool            snapshot;
    bool            reverse;
}

/*
 * #define FDB_KEYSEL_LAST_LESS_THAN(k, l) k, l, 0, 0
 * #define FDB_KEYSEL_LAST_LESS_OR_EQUAL(k, l) k, l, 1, 0
 * #define FDB_KEYSEL_FIRST_GREATER_THAN(k, l) k, l, 1, 1
 * #define FDB_KEYSEL_FIRST_GREATER_OR_EQUAL(k, l) k, l, 0, 1
 */

auto lastLessThan(const Key key)
{
    return Selector(key.dup, false, 0);
}

auto lastLessOrEqual(const Key key)
{
    return Selector(key.dup, true, 0);
}

auto firstGreaterThan(const Key key)
{
    return Selector(key.dup, true, 1);
}

auto firstGreaterOrEqual(const Key key)
{
    return Selector(key.dup, false, 1);
}
