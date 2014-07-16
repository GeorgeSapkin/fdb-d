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
    const Selector      start;
    const Selector      end;
    const int           limit;
    const StreamingMode mode;
    int                 iteration;
    const bool          snapshot;
    const bool          reverse;
}