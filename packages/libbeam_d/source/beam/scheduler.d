module beam.scheduler;

import core.thread.fiber : Fiber;
import core.atomic;
import core.stdc.stdlib : malloc, free;
import beam.types : ActorId;

/**
 * Cooperative M:N fiber scheduler with reduction-based preemption hooks.
 *
 * Phase 1 runs fibers on the calling thread (N=1 worker). The reduction
 * counter mirrors BEAM-style preemption: after `reductionsPerSlice` units
 * of work, the fiber cooperatively yields back to the scheduler.
 *
 * Note: `core.thread.Fiber` is not @nogc; message paths in `beam.mailbox`
 * remain @nogc. Phase 2+ may replace Fiber with a custom stack allocator.
 */
alias FiberFn = void function() nothrow;

enum size_t defaultReductionsPerSlice = 2000;
enum size_t maxRunnable = 256;

struct SchedFiber
{
    Fiber fiber;
    ActorId owner;
    size_t reductionsLeft;
    bool alive;
}

struct Scheduler
{
    private SchedFiber*[maxRunnable] runq;
    private size_t runqLen;
    private size_t reductionsPerSlice;
    private shared size_t nextActorId;
    private SchedFiber* current;

    void init(size_t reductions = defaultReductionsPerSlice) nothrow @trusted
    {
        reductionsPerSlice = reductions == 0 ? defaultReductionsPerSlice : reductions;
        runqLen = 0;
        nextActorId = 1;
        current = null;
        foreach (i; 0 .. maxRunnable)
            runq[i] = null;
    }

    ActorId allocActorId() nothrow @trusted
    {
        return atomicOp!"+="(nextActorId, 1) - 1;
    }

    SchedFiber* currentFiber() nothrow @trusted
    {
        return current;
    }

    bool enqueue(SchedFiber* sf) nothrow @trusted
    {
        if (sf is null || runqLen >= maxRunnable)
            return false;
        runq[runqLen++] = sf;
        return true;
    }

    SchedFiber* spawnFiber(FiberFn fn, ActorId owner) nothrow @trusted
    {
        auto sf = cast(SchedFiber*) malloc(SchedFiber.sizeof);
        if (sf is null)
            return null;
        sf.owner = owner;
        sf.reductionsLeft = reductionsPerSlice;
        sf.alive = true;
        try
        {
            sf.fiber = new Fiber({
                fn();
            });
        }
        catch (Throwable)
        {
            free(sf);
            return null;
        }
        if (!enqueue(sf))
        {
            free(sf);
            return null;
        }
        return sf;
    }

    void tick() nothrow @trusted
    {
        if (current is null)
            return;
        if (current.reductionsLeft == 0)
        {
            current.reductionsLeft = reductionsPerSlice;
            Fiber.yield();
            return;
        }
        current.reductionsLeft--;
    }

    void yieldNow() nothrow @trusted
    {
        if (current !is null)
            current.reductionsLeft = reductionsPerSlice;
        Fiber.yield();
    }

    void runUntilIdle() nothrow @trusted
    {
        size_t spins = 0;
        while (runqLen > 0 && spins < 1_000_000)
        {
            spins++;
            auto sf = runq[0];
            foreach (i; 1 .. runqLen)
                runq[i - 1] = runq[i];
            runqLen--;
            runq[runqLen] = null;

            if (sf is null || !sf.alive || sf.fiber is null)
                continue;

            current = sf;
            if (sf.fiber.state == Fiber.State.TERM)
            {
                sf.alive = false;
                current = null;
                continue;
            }
            try
            {
                sf.fiber.call();
            }
            catch (Throwable)
            {
                sf.alive = false;
                current = null;
                continue;
            }
            current = null;

            if (sf.fiber.state != Fiber.State.TERM && sf.alive)
            {
                if (!enqueue(sf))
                    sf.alive = false;
            }
        }
    }

    size_t runnableCount() const nothrow
    {
        return runqLen;
    }
}

__gshared Scheduler gScheduler;

void ensureScheduler() nothrow @trusted
{
    static bool ready;
    if (!ready)
    {
        gScheduler.init();
        ready = true;
    }
}
