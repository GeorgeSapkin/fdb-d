module fdb.range;

import
    std.array;

import
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.rangeinfo,
    fdb.transaction;

struct Record
{
    Key   key;
    Value value;

    this(Key key, Value value) pure
    {
        this.key   = key;
        this.value = value;
    }
}

struct RecordRange
{
    private Record[]           records;
    private RangeInfo          info;
    private bool               _more;
    private shared Transaction tr;
    private Key                end;
    private ulong              index;

    @property auto more() const pure @nogc
    {
        return _more;
    }

    @property auto length() const pure @nogc
    {
        return records.length;
    }

    this(
        Record[]           records,
        in bool            more,
        RangeInfo          info,
        shared Transaction tr)
    {
        this.records = records;
        this._more   = more;
        this.info    = info;
        this.tr      = tr;

        if (!records.empty)
            this.end = records.back.key.dup;
    }

    @property bool empty() const pure @nogc
    {
        return records.empty;
    }

    auto front() pure @nogc
    {
        return records[0];
    }

    auto popFront()
    {
        records = records[1 .. $];
        ++index;
        if (empty && more)
            fetchNextBatch;
    }

    auto save() pure @nogc
    {
        return this;
    }

    private void fetchNextBatch()
    {
        if (!end || index == info.limit)
        {
            _more = false;
            return;
        }

        if (info.limit > 0)
            info.limit -= index;

        info.iteration++;

        auto batchInfo = info;
        if (batchInfo.reverse)
            batchInfo.end   = end.firstGreaterOrEqual;
        else
            batchInfo.begin = end.firstGreaterThan;

        auto batch  = tr.getRange(batchInfo);
        records     = batch.records;
        _more       = batch.more;

        if (!records.empty)
            end     = records.back.key.dup;
        else
            end     = null;
    }
}
