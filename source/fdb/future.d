module fdb.future;

import
    core.sync.semaphore,
    core.thread;

import
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

alias CompletionCallback = void delegate(Exception ex);

shared class FutureBase(V)
{
    static if (!is(V == void))
    {
        protected V value;
    }

    protected Exception exception;

    abstract shared(V) await();
}

shared class FunctionFuture(alias fun, Args...) : FutureBase!(ReturnType!fun)
{
    alias V = ReturnType!fun;
    alias T = Task!(fun, ParameterTypeTuple!fun) *;
    private T t;

    private Semaphore futureSemaphore;

    this(Args args)
    {
        futureSemaphore = cast(shared)new Semaphore;

        auto cb = args[$-1];
        t = cast(shared)task!fun(
            args[0..$-1],
            (Exception ex)
            {
                cb(ex);
                notify;
            });
        taskPool.put(cast(T)t);
    }

    void notify()
    {
        (cast(Semaphore)futureSemaphore).notify;
    }

    override shared(V) await()
    {
        (cast(Semaphore)futureSemaphore).wait;

        try
        {
            static if (!is(V == void))
                value = (cast(T)t).yieldForce;
            else
                (cast(T)t).yieldForce;
        }
        catch (Exception ex)
        {
            exception = cast(shared)ex;
        }

        enforce(exception is null, cast(Exception)exception);
        static if (!is(V == void))
            return value;
    }
}

class BasicFuture(V)
{
    private Exception   exception;
    private Semaphore   event;

    static if (!is(V == void))
        private V       value;

    this()
    {
        event = new Semaphore;
    }

    static if (!is(V == void))
        void notify(Exception ex, ref V val)
        {
            exception   = ex;
            value       = val;
            event.notify;
        }
    else
        void notify(Exception ex)
        {
            exception   = ex;
            event.notify;
        }

    V await()
    {
        event.wait;
        enforce(exception is null, cast(Exception)exception);
        static if (!is(V == void))
            return value;
    }
}

alias FutureCallback(V) = void delegate(Exception ex, V value);

shared class FDBFutureBase(C, V) : FutureBase!V
{
    private alias SF    = shared FDBFutureBase!(C, V);
    private alias SFH   = shared FutureHandle;
    private alias SE    = shared fdb_error_t;

    private FutureHandle        fh;
    private const Transaction   tr;
    private C                   callbackFunc;

    this(FutureHandle fh, const Transaction tr)
    {
        this.fh = cast(shared)fh;
        this.tr = cast(shared)tr;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        if (fh)
        {
            // NB : Also releases the memory returned by get functions
            fdb_future_destroy(cast(FutureHandle)fh);
            fh = null;
        }
    }

    auto start(C callbackFunc)
    {
        this.callbackFunc = cast(shared)callbackFunc;
        const auto err = fdb_future_set_callback(
            cast(FutureHandle) fh,
            cast(FDBCallback)  &futureReady,
            cast(void*)        this);
        enforceError(err);

        return this;
    }

    shared(V) await(C callbackFunc)
    {
        if (callbackFunc)
            start(callbackFunc);

        shared err = fdb_future_block_until_ready(cast(FutureHandle)fh);
        if (err != FDBError.NONE)
        {
            exception = cast(shared)err.toException;
            enforce(exception is null, cast(Exception)exception);
        }

        static if (!is(V == void))
            value  = cast(shared)extractValue(fh, err);

        exception  = cast(shared)err.toException;

        enforce(exception is null, cast(Exception)exception);
        static if (!is(V == void))
            return value;
    }

    override shared(V) await()
    {
        static if (!is(V == void))
            return await(null);
        else
            await(null);
    }

    extern(C) static void futureReady(SFH f, SF thiz)
    {
        thread_attachThis;
        auto futureTask = task!worker(f, thiz);
        // or futureTask.executeInNewThread?
        taskPool.put(futureTask);
    }

    static void worker(SFH f, SF thiz)
    {
        scope (exit) delete thiz;

        shared fdb_error_t err;
        with (thiz)
        {
            static if (is(V == void))
            {
                extractValue(cast(shared)f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(err.toException);
            }
            else
            {
                auto value = extractValue(cast(shared)f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(err.toException, value);
            }
        }
    }

    abstract V extractValue(SFH fh, out SE err);
}

private mixin template FDBFutureCtor()
{
    this(FutureHandle fh, const Transaction tr = null)
    {
        super(fh, tr);
    }
}

alias ValueFutureCallback = FutureCallback!Value;

shared class ValueFuture : FDBFutureBase!(ValueFutureCallback, Value)
{
    mixin FDBFutureCtor;

    private alias PValue = ubyte *;

    override Value extractValue(SFH fh, out SE err)
    {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(
            cast(FutureHandle)fh,
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
    mixin FDBFutureCtor;

    private alias PKey = ubyte *;

    override Key extractValue(SFH fh, out SE err)
    {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(
            cast(FutureHandle)fh,
            &key,
            &keyLength);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return key[0..keyLength];
    }
}

alias VoidFutureCallback = void delegate(Exception ex);

shared class VoidFuture : FDBFutureBase!(VoidFutureCallback, void)
{
    mixin FDBFutureCtor;

    override void extractValue(SFH fh, out SE err)
    {
        err = fdb_future_get_error(
            cast(FutureHandle)fh);
    }
}

alias KeyValueFutureCallback    = FutureCallback!RecordRange;
alias ForEachCallback           = void delegate(Record record);
alias BreakableForEachCallback  = void delegate(
    Record record,
    out bool breakLoop);

shared class KeyValueFuture
    : FDBFutureBase!(KeyValueFutureCallback, RecordRange)
{
    const RangeInfo info;

    this(FutureHandle fh, const Transaction tr, RangeInfo info)
    {
        super(fh, tr);

        this.info = cast(shared)info;
    }

    override RecordRange extractValue(SFH fh, out SE err)
    {
        FDBKeyValue * kvs;
        int len;
        // Receives true if there are more result, or false if all results have
        // been transmitted
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(
            cast(FutureHandle)fh,
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
        auto key   = (cast(Key)  kv.key  [0..kv.key_length  ]).dup;
        auto value = (cast(Value)kv.value[0..kv.value_length]).dup;
        return Record(key, value);
    }

    auto forEach(FC)(FC fun, CompletionCallback cb)
    {
        auto f = createFuture!(foreachTask!FC)(this, fun, cb);
        return f;
    }

    static void foreachTask(FC)(
        shared KeyValueFuture future,
        FC                    fun,
        CompletionCallback    cb)
    {
        try
        {
            // This will block until value is ready
            auto range = cast(RecordRange)future.await;
            foreach (kv; range)
            {
                static if (arity!fun == 2)
                {
                    bool breakLoop;
                    fun(kv, breakLoop);
                    if (breakLoop) break;
                }
                else
                    fun(kv);
            }

            cb(null);
        }
        catch (Exception ex)
        {
            cb(ex);
        }
    }
}

alias VersionFutureCallback = FutureCallback!ulong;

shared class VersionFuture : FDBFutureBase!(VersionFutureCallback, ulong)
{
    mixin FDBFutureCtor;

    override ulong extractValue(SFH fh, out SE err)
    {
        long ver;
        err = fdb_future_get_version(
            cast(FutureHandle)fh,
            &ver);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return ver;
    }
}

alias StringFutureCallback = FutureCallback!(string[]);

shared class StringFuture : FDBFutureBase!(StringFutureCallback, string[])
{
    mixin FDBFutureCtor;

    override string[] extractValue(SFH fh, out SE err)
    {
        char ** stringArr;
        int     count;
        err = fdb_future_get_string_array(
            cast(FutureHandle)fh,
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
    mixin FDBFutureCtor;

    ~this()
    {
        cancel;
    }

    void cancel()
    {
        if (fh)
            fdb_future_cancel(cast(FutureHandle)fh);
    }
}

auto createFuture(T)()
{
    auto future = new BasicFuture!T;
    return future;
}

auto createFuture(F, Args...)(Args args)
{
    auto future = new shared F(args);
    return future;
}

auto createFuture(alias fun, Args...)(Args args)
if (isSomeFunction!fun)
{
    auto future = new shared FunctionFuture!(fun, Args)(args);
    return future;
}

auto startOrCreateFuture(F, C, Args...)(
    Args args,
    C callback)
{
    auto future = createFuture!F(args);
    if (callback)
        future.start(callback);
    return future;
}

void await(F...)(F futures)
{
    foreach (f; futures)
        f.await;
}
