module fdb.context;

import
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo,
    fdb.traits;

alias WorkFunc = void delegate(IDatabaseContext ctx);

interface IDatabaseContext
{
    Value opIndex(in Key key);
    final Value opIndex (in Key key) shared
    {
        return this.unshare.opIndex(key);
    }

    RecordRange opIndex(RangeInfo info);
    final RecordRange opIndex(RangeInfo info) shared
    {
        return this.unshare.opIndex(info);
    }

    inout(Value) opIndexAssign(inout(Value) value, in Key key);
    final inout(Value) opIndexAssign(inout(Value) value, in Key key) shared
    {
        return this.unshare.opIndexAssign(value, key);
    }

    void clear(in Key key);
    final void clear(in Key key) shared
    {
        return this.unshare.clear(key);
    }

    void clearRange(in RangeInfo info);
    final void clearRange(in RangeInfo info) shared
    {
        return this.unshare.clearRange(info);
    }

    void run(in WorkFunc func);
    final void run(in WorkFunc func) shared
    {
        return this.unshare.run(func);
    }
}
