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
    fdb.transaction;

alias CompletionCallback = void delegate(Exception ex);

private mixin template ExceptionCtorMixin() {
    this(string msg = null, Throwable next = null) { super(msg, next); }
    this(string msg, string file, size_t line, Throwable next = null) {
        super(msg, file, line, next);
    }
}

class FutureException : Exception { mixin ExceptionCtorMixin; }

shared class FutureBase(V)
{
    static if (!is(V == void))
    {
        protected V value;
    }

    protected Exception exception;

    abstract shared(V) await();
}

shared class FunctionFuture(alias fun, bool pool = true, Args...) :
    FutureBase!(ReturnType!fun),

    // dummy implementation to allow storage in KeyValueFuture
    IDisposable
{
    alias V = ReturnType!fun;
    alias T = Task!(fun, ParameterTypeTuple!fun) *;
    private T t;

    this(Args args)
    {
        t = cast(shared)task!fun(args);
        auto localTask = cast(T)t;
        static if (pool)
            taskPool.put(localTask);
        else
            localTask.executeInNewThread;
    }

    void dispose() {}

    override shared(V) await()
    {
        try
        {
            auto localTask = cast(T)t;
            static if (!is(V == void))
                value = localtask.yieldForce;
            else
                localTask.yieldForce;
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
        auto complete = event.wait(5.seconds);
        if (!complete)
            throw new FutureException("Operation timed out");

        Exception ex = cast(Exception) this.exception;
        if (ex is null)
        {
            static if (!is(V == void))
                return value;
            else
                return;
        }

        throw ex;
    }
}

alias FutureCallback(V) = void delegate(Exception ex, V value);

shared class FDBFutureBase(C, V) : FutureBase!V, IDisposable
{
    private alias SF    = shared FDBFutureBase!(C, V);
    private alias SFH   = shared FutureHandle;
    private alias SE    = shared fdb_error_t;

    private FutureHandle fh;
    private Transaction  tr;
    private C            callbackFunc;

    this(FutureHandle fh, shared Transaction tr)
    {
        this.fh = cast(shared)fh;
        this.tr = tr;
    }

    ~this()
    {
        dispose;
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
        if (err != FDBError.SUCCESS)
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
    this(FutureHandle fh, shared Transaction tr = null)
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
        if (err != FDBError.SUCCESS || !valuePresent)
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
        if (err != FDBError.SUCCESS)
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

alias KeyValueFutureCallback   = FutureCallback!RecordRange;
alias ForEachCallback          = void delegate(Record record);
alias BreakableForEachCallback = void delegate(
    Record   record,
    out bool breakLoop);

shared class KeyValueFuture
    : FDBFutureBase!(KeyValueFutureCallback, RecordRange)
{
    const RangeInfo info;

    private IDisposable[] futures;

    this(FutureHandle fh, shared Transaction tr, RangeInfo info)
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
        auto future  = createFuture!(foreachTask!FC)(this, fun, cb);
        synchronized (this)
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
        if (err != FDBError.SUCCESS)
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
        if (err != FDBError.SUCCESS)
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

auto createFuture(alias fun, bool pool = true, Args...)(Args args)
if (isSomeFunction!fun)
{
    auto future = new shared FunctionFuture!(fun, pool, Args)(args);
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
