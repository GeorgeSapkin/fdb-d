module fdb.direct;

import
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo;

shared interface IDirect
{
    shared(Value) opIndex       (const Key key);
    RecordRange   opIndex       (RangeInfo info);
    inout(Value)  opIndexAssign (inout(Value) value, const Key key);
}
