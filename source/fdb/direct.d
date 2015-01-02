module fdb.direct;

import
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo;

alias SimpleWorkFunc = void delegate(shared IDirect tr);

shared interface IDirect
{
    shared(Value) opIndex       (const Key key);
    RecordRange   opIndex       (RangeInfo info);
    inout(Value)  opIndexAssign (inout(Value) value, const Key key);

    void clear(const Key key);
    void clearRange(const RangeInfo info);

    void run(SimpleWorkFunc func);
}
