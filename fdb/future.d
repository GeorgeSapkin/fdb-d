module fdb.future;

import std.algorithm,
       std.exception,
       std.parallelism;

import fdb.fdb_c;

alias Key     = ubyte[];
alias PKey    = ubyte *;
alias Value   = ubyte[];
alias PValue  = ubyte *;
alias Records = Value[Key];

class Future(C, V) {
    private alias P = Future!(C, V);
    private alias T = Task!(worker, P);

    private FDBFuture * future;
    private C           callbackFunc;
    private T         * futureTask;

    @disable this();
    this(FDBFuture * future, C callbackFunc) {
        this.future       = future;
        this.callbackFunc = callbackFunc;
    }

    ~this() { destroy; }

    void destroy() { fdb_future_destroy(future); }

    void start() {
        fdb_error_t err = fdb_future_set_callback(future, futureReady, this);
        // TODO : is there no fdb_get_error for that error code?
        // NodeCallback.h line 58
        enforce(!err, "fdb_future_set_callback failed");
    }

    private static void futureReady(P thiz) {
        futureTask = task!worker(this);
        // or futureTask.executeInNewThread?
        taskPoll.put(futureTask);
    }

    private static void worker(P thiz) {
        fdb_error_t err;
        auto value = thiz.extractValue(thiz.future, err);
        thiz.callbackFunc(err, value);
    }

    abstract V extractValue(FDBFuture * future, out fdb_error_t err = 0);
}

private mixin template FutureCtor(C) {
    @disable this();
    this(FDBFuture * future, C callbackFunc) {
        super(future, callbackFunc);
    }
}

class ValueFuture(C) : Future!(C, Value) {
    mixin FutureCtor!C;

    override Value extractValue(FDBFuture * future, out fdb_error_t err) {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(future,
                                   &valuePresent,
                                   cast(PValue *) &value,
                                   &valueLength);
        if (err || !valuePresent) return null;
        return value[0..valueLength];
    }
}

class KeyFuture(C) : Future!(C, Key) {
    mixin FutureCtor!C;

    override Value extractValue(FDBFuture * future, out fdb_error_t err) {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(future, cast(PValue *) &key, &keyLength);
        if (err) return typeof(return).init;
        return key[0..keyLength];
    }
}

class VoidFuture(C) : Future!(C, void) {
    mixin FutureCtor!C;

    override void extractValue(FDBFuture * future, out fdb_error_t err) {
        err = fdb_future_get_error(future);
    }
}

class KeyValueFuture(C) : Future!(C, Records) {
    mixin FutureCtor!C;

    override Records extractValue(FDBFuture * future, out fdb_error_t err) {
        FDBKeyValue * kv;
        int len;
        // TODO : sup with more?
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(future, &kv, &len, &more);
        if (err) return typeof(return).init;

        auto tuples = reduce!
            ((a, b) => {
                a[b.key[0..b.key_length]] = b.value[0..b.value_length];
                return a;
            })
            (new Records, kv[0..len]);
        return tuples;
    }
}

class VersionFuture(C) : Future!(C, ulong) {
    mixin FutureCtor!C;

    override ulong extractValue(FDBFuture * future, out fdb_error_t err) {
        ulong ver;
        err = fdb_future_get_version(future, &ver);
        if (err) return typeof(return).init;
        return ver;
    }
}

class StringFuture(C) : Future!(C, string[]) {
    mixin FutureCtor!C;

    override string[] extractValue(FDBFuture * future, out fdb_error_t err) {
        ubyte ** stringArr;
        int      count;
        err = fdb_future_get_string_array(future, &stringArr, &count);
        if (err) return typeof(return).init;
        auto strings = stringArr[0..count].map!(to!string);
        return strings;
    }
}

class WatchFuture(C) : VoidFuture!C {
    mixin FutureCtor!C;
    ~this() { cancel; }
    void cancel() { if (future) fdb_future_cancel(future); }
}