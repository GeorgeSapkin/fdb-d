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

    @property auto more()
    {
        return _more;
    }

    @property auto length()
    {
        return records.length;
    }

    this(
        Record[]           records,
        const bool         more,
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

    @property bool empty() const
    {
        return records.length == 0;
    }

    auto front()
    {
        return records[0];
    }

    auto popFront()
    {
        records = records[1 .. $];
        if (empty && more)
            fetchNextBatch;
    }

    auto save()
    {
        return this;
    }

    private void fetchNextBatch()
    {
        if (!end)
        {
            _more = false;
            return;
        }

        info.iteration++;

        auto batchInfo = info;
        if (batchInfo.reverse)
            batchInfo.end   = end.firstGreaterOrEqual;
        else
            batchInfo.begin = end.firstGreaterThan;

        auto future = tr.getRange(batchInfo);
        auto batch  = cast(RecordRange)future.await;
        records    ~= batch.records;
        _more       = batch.more;

        if (!records.empty)
            end     = records.back.key.dup;
        else
            end     = null;
    }
}
