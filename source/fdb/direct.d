module fdb.direct;

import
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo;

alias SimpleWorkFunc = void delegate(shared IDirect tr);

shared interface IDirect
{
    shared(Value) opIndex       (in Key key);
    RecordRange   opIndex       (RangeInfo info);
    inout(Value)  opIndexAssign (inout(Value) value, in Key key);

    void clear(in Key key);
    void clearRange(in RangeInfo info);

    void run(SimpleWorkFunc func);
}
