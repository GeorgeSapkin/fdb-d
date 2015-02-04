import
    std.algorithm,
    std.array,
    std.conv,
    std.c.stdlib,
    std.exception,
    std.parallelism,
    std.random,
    std.range,
    std.stdio,
    std.traits;

import
    fdb,
    fdb.tuple;

shared Database db;

static const auto levels = [ "intro", "for dummies", "remedial", "101", "201",
    "301", "mastery", "lab", "seminar" ];

static const auto types = [ "chem", "bio", "cs", "geometry", "calc", "alg",
    "film", "music", "art", "dance" ];

static const auto classNames = initClassNames;

// Generates 1,620 classes like '9:00 chem for dummies'
auto initClassNames()
{
    string[] classNames;
    foreach (level; levels)
        foreach (type; types)
            foreach (hour; 2..20)
                classNames ~= hour.to!string ~ ":00 " ~ type ~ " " ~ level;

    return classNames;
}

void addClass(T)(T tr, const string c)
{
    tr[pack("class", c)] = pack(100);
}

void init(shared IDatabaseContext ctx)
{
    ctx.run((tr)
    {
        tr.clearRange(pack("attends").range);
        tr.clearRange(pack("class").range);
        foreach (className; classNames)
            addClass(tr, className);
    });
}

void runSim(const uint students, const uint opsPerStudent)
{
    alias T = Task!(simulateStudents, ParameterTypeTuple!simulateStudents) *;

    T[] tasks;
    foreach(const s; 0..students)
    {
        auto t = task!simulateStudents(s, opsPerStudent);
        taskPool.put(t);
        tasks ~= t;
    }
    foreach(t; tasks)
        t.yieldForce;

    writefln("Ran %s transactions", students * opsPerStudent);
}

auto remove(T)(T[] ar, T c)
{
    return reduce!((a, b) { return b != c ? a ~ b : a; })(new T[0], ar);
}

void simulateStudents(const uint i, const uint ops)
{
    auto studentId  = "s" ~ i.to!string;
    auto allClasses = classNames.dup;

    string[] myClasses;
    string c, oldC, newC;
    auto rand = new Random();

    enum Mood { ADD, SWITCH, DROP }

    foreach (j; 0..ops)
    {
        auto classCount = myClasses.length;
        Mood[] moods;
        if (classCount > 0)
            moods ~= [Mood.DROP, Mood.SWITCH];

        if (classCount < 5)
            moods ~= Mood.ADD;
        auto mood = moods[uniform(0, moods.length)];

        try
        {
            if (allClasses.empty)
                allClasses = availableClasses(db);

            if (mood == Mood.ADD)
            {
                c = allClasses[uniform(0, allClasses.length)];
                signup(db, studentId, c);
                myClasses ~= c;
            }

            else if (mood == Mood.DROP)
            {
                c = myClasses[uniform(0, myClasses.length)];
                drop(db, studentId, c);
                myClasses = myClasses.remove(c);
            }

            else if (mood == Mood.SWITCH)
            {
                oldC = myClasses[uniform(0, myClasses.length)];
                newC = allClasses[uniform(0, allClasses.length)];
                switchClasses(db, studentId, oldC, newC);
                myClasses  = myClasses.remove(oldC);
                myClasses ~= newC;
            }
        }
        catch (Exception e)
        {
            writeln(e.msg ~ " Need to recheck available classes.");
            allClasses = new string[0];
        }
    }
}

auto availableClasses(shared IDatabaseContext ctx)
{
    shared string[] classNames;

    ctx.run((tr)
    {
        auto classes = tr[pack("class").range];
        foreach(c; classes)
            if (c.value.unpack!long > 0)
                classNames ~= c.key.unpack.back.get!string;
    });

    return cast(string[]) classNames;
}

void signup(shared IDatabaseContext ctx, const string s, const string c)
{
    ctx.run((tr)
    {
        auto rec = pack("attends", s, c);
        if (tr[rec] !is null)
            return; // already signed up

        auto seatsLeft = tr[pack("class", c)].unpack!long;
        enforce(seatsLeft != 0, "No remaining seats");

        auto classes = tr[pack("attends", s).range];
        enforce(classes.length < 5, "Too many classes");

        tr[pack("class", c)] = pack(seatsLeft - 1);
        tr[rec]              = pack("");
    });
}

void drop(shared IDatabaseContext ctx, const string s, const string c)
{
    ctx.run((tr)
    {
        auto rec = pack("attends", s, c);
        if (tr[rec] is null)
            return; // not taking this class

        auto classKey = pack("class", c);
        tr[classKey]  = pack(tr[classKey].unpack!long + 1);
        tr.clear(rec);
    });
  }

void switchClasses(
    shared IDatabaseContext ctx,
    const string            s,
    const string            oldC,
    const string            newC)
{
    ctx.run((tr)
    {
        drop(tr, s, oldC);
        signup(tr, s, newC);
    });
}

void handleException(E)(E ex)
{
    ex.writeln;
    fdb.close;
    exit(1);
}

void main()
{
    try db = fdb.open;
    catch (FDBException ex) ex.handleException;

    scope (exit) fdb.close;

    init(db);
    "Initialized".writeln;

    runSim(10, 10);
}
