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
    fdb.disposable,
    fdb.error,
    fdb.fdb_c,
    fdb.range,
    fdb.rangeinfo,
    fdb.traits,
    fdb.transaction;

alias CompletionCallback = void delegate(Exception ex);

private mixin template ExceptionCtorMixin()
{
    this(string msg = null, Throwable next = null)
    {
        super(msg, next);
    }

    this(string msg, string file, size_t line, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

class FutureException : Exception
{
    mixin ExceptionCtorMixin;
}

class FutureBase(V)
{
    static if (!is(V == void))
        protected V value;

    protected Exception exception;

    abstract V await();
}

class FunctionFuture(alias fun, bool pool = true, Args...) :
    FutureBase!(ReturnType!fun),

    // dummy implementation to allow storage in KeyValueFuture
    IDisposable
{
    alias V = ReturnType!fun;
    alias T = Task!(fun, ParameterTypeTuple!fun) *;
    private T t;

    this(Args args)
    {
        t = task!fun(args);
        static if (pool)
            taskPool.put(t);
        else
            t.executeInNewThread;
    }

    void dispose() {}

    override V await()
    {
        try
        {
            static if (!is(V == void))
                value = t.yieldForce;
            else
                t.yieldForce;
        }
        catch (Exception ex)
            exception = ex;

        enforce(exception is null, exception);
        static if (!is(V == void))
            return value;
    }
}

alias FutureCallback(V) = void delegate(Exception ex, V value);

class FDBFutureBase(C, V) : FutureBase!V, IDisposable
{
    private alias SF  = shared FDBFutureBase!(C, V);
    private alias SFH = shared FutureHandle;
    private alias SE  = shared fdb_error_t;

    private FutureHandle fh;
    private Transaction  tr;
    private C            callbackFunc;

    this(FutureHandle fh, Transaction tr)
    {
        this.fh = fh;
        this.tr = tr;
    }

    void dispose()
    {
        if (!fh) return;

        // NB : Also releases the memory returned by get functions
        fdb_future_destroy(cast(FutureHandle)fh);
        fh = null;
    }

    auto start(C callbackFunc)
    {
        this.callbackFunc = callbackFunc;
        const err = fdb_future_set_callback(
            fh,
            cast(FDBCallback)&futureReady,
            cast(void*)cast(shared)this);
        enforceError(err);

        return this;
    }

    V await(C callbackFunc)
    {
        if (callbackFunc)
            start(callbackFunc);

        const err = fdb_future_block_until_ready(fh);
        if (err != FDBError.SUCCESS)
        {
            exception = err.toException;
            enforce(exception is null, exception);
        }

        static if (!is(V == void))
            value = extractValue(fh, err);
        else
            extractValue(fh, err);

        exception = err.toException;

        enforce(exception is null, exception);
        static if (!is(V == void))
            return value;
    }

    override V await()
    {
        static if (!is(V == void))
            return await(null);
        else
            await(null);
    }

    V await() shared
    {
        static if (!is(V == void))
            return this.unshare.await(null);
        else
            this.unshare.await(null);
    }

    extern(C) static void futureReady(FutureHandle f, SF thiz)
    {
        thread_attachThis;
        auto futureTask = task!worker(f, thiz);
        // or futureTask.executeInNewThread?
        taskPool.put(futureTask);
    }

    static void worker(FutureHandle f, SF thiz)
    {
        fdb_error_t err;
        with (cast(FDBFutureBase!(C, V))thiz)
            static if (is(V == void))
            {
                extractValue(f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(err.toException);
            }
            else
            {
                auto value = extractValue(f, err);
                if (callbackFunc)
                    (cast(C)callbackFunc)(err.toException, value);
            }
    }

    abstract V extractValue(FutureHandle fh, out fdb_error_t err);
}

private mixin template FDBFutureCtor()
{
    this(FutureHandle fh, Transaction tr = null)
    {
        super(fh, tr);
    }
}

alias ValueFutureCallback = FutureCallback!Value;

class ValueFuture : FDBFutureBase!(ValueFutureCallback, Value)
{
    mixin FDBFutureCtor;

    private alias PValue = ubyte *;

    override Value extractValue(FutureHandle fh, out fdb_error_t err)
    {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(fh, &valuePresent, &value, &valueLength);
        if (err != FDBError.SUCCESS || !valuePresent)
            return null;
        return value[0..valueLength];
    }
}

alias KeyFutureCallback = FutureCallback!Key;

class KeyFuture : FDBFutureBase!(KeyFutureCallback, Key)
{
    mixin FDBFutureCtor;

    private alias PKey = ubyte *;

    override Key extractValue(FutureHandle fh, out fdb_error_t err)
    {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(fh, &key, &keyLength);
        if (err != FDBError.SUCCESS)
            return typeof(return).init;
        return key[0..keyLength];
    }
}

alias VoidFutureCallback = void delegate(Exception ex);

class VoidFuture : FDBFutureBase!(VoidFutureCallback, void)
{
    mixin FDBFutureCtor;

    override void extractValue(FutureHandle fh, out fdb_error_t err)
    {
        err = fdb_future_get_error(fh);
    }
}

alias KeyValueFutureCallback   = FutureCallback!RecordRange;
alias ForEachCallback          = void delegate(Record record);
alias BreakableForEachCallback = void delegate(
    Record   record,
    out bool breakLoop);

class KeyValueFuture
    : FDBFutureBase!(KeyValueFutureCallback, RecordRange)
{
    const RangeInfo info;

    private IDisposable[] futures;
    private shared auto futureLock = new Object;

    this(FutureHandle fh, Transaction tr, RangeInfo info)
    {
        super(fh, tr);

        this.info = info;
    }

    override void dispose()
    {
        synchronized (futureLock)
            foreach (future; futures)
                future.dispose;

        super.dispose;
    }

    override RecordRange extractValue(FutureHandle fh, out fdb_error_t err)
    {
        FDBKeyValue * kvs;
        int len;

        // Receives true if there are more result, or false if all results have
        // been transmitted
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(fh, &kvs, &len, &more);
        if (err != FDBError.SUCCESS)
            return typeof(return).init;

        auto records = minimallyInitializedArray!(Record[])(len);
        foreach (i, kv; kvs[0..len])
        {
            records[i].key   = (cast(Key)  kv.key  [0..kv.key_length  ]).dup;
            records[i].value = (cast(Value)kv.value[0..kv.value_length]).dup;
        }

        return RecordRange(
            records,
            cast(bool)more,
            cast(RangeInfo)info,
            tr);
    }

    auto forEach(FC)(FC fun, CompletionCallback cb)
    {
        auto future  = createFuture!(foreachTask!FC)(this.share, fun, cb);
        synchronized (futureLock)
            futures ~= future;
        return future;
    }

    static void foreachTask(FC)(
        shared KeyValueFuture future,
        FC                    fun,
        CompletionCallback    cb)
    {
        try
        {
            // This will block until value is ready
            auto range = future.await;
            foreach (kv; range)
                static if (arity!fun == 2)
                {
                    bool breakLoop;
                    fun(kv, breakLoop);
                    if (breakLoop) break;
                }
                else
                    fun(kv);

            cb(null);
        }
        catch (Exception ex)
            cb(ex);
    }
}

alias VersionFutureCallback = FutureCallback!ulong;

class VersionFuture : FDBFutureBase!(VersionFutureCallback, ulong)
{
    mixin FDBFutureCtor;

    override ulong extractValue(FutureHandle fh, out fdb_error_t err)
    {
        long ver;
        err = fdb_future_get_version(fh, &ver);
        if (err != FDBError.SUCCESS)
            return typeof(return).init;
        return ver;
    }
}

alias StringFutureCallback = FutureCallback!(string[]);

class StringFuture : FDBFutureBase!(StringFutureCallback, string[])
{
    mixin FDBFutureCtor;

    override string[] extractValue(FutureHandle fh, out fdb_error_t err)
    {
        char ** stringArr;
        int     count;
        err = fdb_future_get_string_array(fh, &stringArr, &count);
        if (err != FDBError.SUCCESS)
            return typeof(return).init;
        auto strings = stringArr[0..count].map!(to!string).array;
        return strings;
    }
}

class WatchFuture : VoidFuture
{
    mixin FDBFutureCtor;

    void cancel()
    {
        if (fh)
            fdb_future_cancel(cast(FutureHandle)fh);
    }
}

auto createFuture(F, Args...)(Args args)
{
    auto future = new F(args);
    return future;
}

auto createFuture(alias fun, bool pool = true, Args...)(Args args)
if (isSomeFunction!fun)
{
    auto future = new FunctionFuture!(fun, pool, Args)(args);
    return future;
}

auto startOrCreateFuture(F, C, Args...)(Args args, C callback)
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
