module fdb.future;

import
    core.sync.semaphore,
    core.thread,
    std.algorithm,
    std.array,
    std.conv,
    std.exception,
    std.parallelism,
    std.traits;

import
    fdb.error,
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo,
    fdb.transaction;

private alias PKey      = ubyte *;
private alias PValue    = ubyte *;

alias CompletionCallback = void delegate(Exception ex);

class Future(alias fun, Args...)
{
    alias V = ReturnType!fun;
    private Task!(fun, ParameterTypeTuple!fun) * t;

    private Semaphore futureSemaphore;

    this(Args args)
    {
        futureSemaphore = new Semaphore;

        t = task!fun(
            args,
            (Exception ex)
            {
                notify;
            });
        taskPool.put(t);
    }

    void notify()
    {
        futureSemaphore.notify;
    }

    auto wait()
    {
        futureSemaphore.wait;
        return this;
    }

    static if (!is(V == void))
    {
        V getValue()
        {
            return t.yieldForce;
        }
    }
}

alias FutureCallback(V) = void delegate(FDBException ex, V value);

shared class FDBFutureBase(C, V)
{
    private alias SF = shared FDBFutureBase!(C, V);
    private alias SH = shared FutureHandle;
    private alias SE = shared fdb_error_t;

    private FutureHandle        future;
    private const Transaction   tr;
    private C                   callbackFunc;

    this(FutureHandle future, const Transaction tr)
    {
        this.future = cast(shared)future;
        this.tr     = cast(shared)tr;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        if (future)
        {
            // NB : Also releases the memory returned by get functions
            fdb_future_destroy(cast(FutureHandle)future);
            future = null;
        }
    }

    auto start(C callbackFunc)
    {
        this.callbackFunc = cast(shared)callbackFunc;
        const auto err = fdb_future_set_callback(
            cast(FutureHandle) future,
            cast(FDBCallback)  &futureReady,
            cast(void*)        this);
        enforceError(err);

        return this;
    }

    auto wait(C callbackFunc = null)
    {
        if (callbackFunc)
            start(callbackFunc);

        enforceError(fdb_future_block_until_ready(cast(FutureHandle)future));

        return this;
    }

    extern(C) static void futureReady(SH f, SF thiz)
    {
        thread_attachThis;
        auto futureTask = task!worker(f, thiz);
        // or futureTask.executeInNewThread?
        taskPool.put(futureTask);
    }

    static void worker(SH f, SF thiz)
    {
        scope (exit) delete thiz;

        shared fdb_error_t err;
        with (thiz)
        {
            static if (is(V == void))
            {
                extractValue(cast(shared)f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(new FDBException(err));
            }
            else
            {
                auto value = extractValue(cast(shared)f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(new FDBException(err), value);
            }
        }
    }

    static if (!is(V == void))
    {
        /**
         * Blocks until value is loaded and returns it
         */
        V getValue()
        {
            wait;
            shared fdb_error_t err;
            auto value = extractValue(future, err);
            enforceError(err);
            return value;
        }
    }

    abstract V extractValue(SH future, out SE err);
}

private mixin template FutureCtor(C)
{
    this(FutureHandle future, const Transaction tr = null)
    {
        super(future, tr);
    }
}

alias ValueFutureCallback = FutureCallback!Value;

shared class ValueFuture : FDBFutureBase!(ValueFutureCallback, Value)
{
    mixin FutureCtor!ValueFutureCallback;

    override Value extractValue(SH future, out SE err)
    {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(
            cast(FutureHandle)future,
            &valuePresent,
            &value,
            &valueLength);
        if (err != FDBError.NONE || !valuePresent)
            return null;
        return value[0..valueLength];
    }
}

alias KeyFutureCallback = FutureCallback!Key;

shared class KeyFuture : FDBFutureBase!(KeyFutureCallback, Key)
{
    mixin FutureCtor!KeyFutureCallback;

    override Value extractValue(SH future, out SE err)
    {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(
            cast(FutureHandle)future,
            &key,
            &keyLength);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return key[0..keyLength];
    }
}

alias VoidFutureCallback = void delegate(FDBException ex);

shared class VoidFuture : FDBFutureBase!(VoidFutureCallback, void)
{
    mixin FutureCtor!VoidFutureCallback;

    override void extractValue(SH future, out SE err)
    {
        err = fdb_future_get_error(
            cast(FutureHandle)future);
    }
}

alias KeyValueFutureCallback    = FutureCallback!RecordRange;
alias ForEachCallback           = void delegate(Record record);

shared class KeyValueFuture
    : FDBFutureBase!(KeyValueFutureCallback, RecordRange)
{
    const RangeInfo info;

    this(FutureHandle future, const Transaction tr, RangeInfo info)
    {
        super(future, tr);

        this.info = cast(shared)info;
    }

    override RecordRange extractValue(SH future, out SE err)
    {
        FDBKeyValue * kvs;
        int len;
        // Receives true if there are more result, or false if all results have
        // been transmited
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(
            cast(FutureHandle)future,
            &kvs,
            &len,
            &more);
        if (err != FDBError.NONE)
            return typeof(return).init;

        Record[] records = kvs[0..len]
            .map!createRecord
            .array;

        return RecordRange(
            records,
            cast(bool)more,
            cast(RangeInfo)info,
            cast(Transaction)tr);
    }

    static Record createRecord(ref FDBKeyValue kv) pure
    {
        auto key   = (cast(Key)  kv.key  [0..kv.key_length  ]).idup;
        auto value = (cast(Value)kv.value[0..kv.value_length]).idup;
        return Record(key, value);
    }

    auto forEach(ForEachCallback fun, CompletionCallback cb)
    {
        auto f = createFuture!foreachTask(this, fun, cb);
        return f;
    }

    // TODO : this is bullshit signature
    static void foreachTask(
        shared KeyValueFuture   future,
        ForEachCallback         fun,
        CompletionCallback      cb,
        CompletionCallback      notifyCb)
    {
        try
        {
            auto range = future.getValue;
            foreach (kv; range)
                fun(kv);
            cb(null);
            notifyCb(null);
        }
        catch (Exception ex)
        {
            cb(ex);
            notifyCb(ex);
        }
    }
}

alias VersionFutureCallback = FutureCallback!ulong;

shared class VersionFuture : FDBFutureBase!(VersionFutureCallback, ulong)
{
    mixin FutureCtor!VersionFutureCallback;

    override ulong extractValue(SH future, out SE err)
    {
        long ver;
        err = fdb_future_get_version(
            cast(FutureHandle)future,
            &ver);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return ver;
    }
}

alias StringFutureCallback = FutureCallback!(string[]);

shared class StringFuture : FDBFutureBase!(StringFutureCallback, string[])
{
    mixin FutureCtor!StringFutureCallback;

    override string[] extractValue(SH future, out SE err)
    {
        char ** stringArr;
        int     count;
        err = fdb_future_get_string_array(
            cast(FutureHandle)future,
            &stringArr,
            &count);
        if (err != FDBError.NONE)
            return typeof(return).init;
        auto strings = stringArr[0..count].map!(to!string).array;
        return strings;
    }
}

shared class WatchFuture : VoidFuture
{
    mixin FutureCtor!VoidFutureCallback;

    ~this()
    {
        cancel;
    }

    void cancel()
    {
        if (future)
            fdb_future_cancel(cast(FutureHandle)future);
    }
}

auto createFuture(F, Args...)(Args args)
{
    auto _future = new shared F(args);
    return _future;
}

auto createFuture(alias fun, Args ...)(Args args)
if (isSomeFunction!fun)
{
    auto _future = new Future!(fun, Args)(args);
    return _future;
}

auto startOrCreateFuture(F, C, Args...)(
    Args args,
    C callback)
{
    auto _future = new shared F(args);
    if (callback)
        _future.start(callback);
    return _future;
}

void wait(F ...)(F futures)
{
    foreach (f; futures)
        f.wait;
}