module fdb.range;

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
    private Record[]    records;
    private RangeInfo   info;
    private bool        _more;
    private Transaction tr;

    @property auto more()
    {
        return _more;
    }

    @property auto length()
    {
        return records.length;
    }

    this(
        Record[]    records,
        const bool  more,
        RangeInfo   info,
        Transaction tr)
    {
        this.records    = records;
        this._more      = more;
        this.info       = info;
        this.tr         = tr;
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
        info.iteration++;
        auto future = tr.getRange(info);
        auto batch  = cast(RecordRange)future.value;
        records    ~= batch.records;
        _more       = batch.more;
    }
}