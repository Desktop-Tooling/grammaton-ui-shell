module beam.actor;

import core.stdc.stdlib : malloc, free;
import beam.types : ActorId, Message, invalidActorId;
import beam.mailbox : Mailbox;
import beam.scheduler : Scheduler, SchedFiber, gScheduler, ensureScheduler, FiberFn;

/**
 * Actor = mailbox + fiber + identity.
 * Behavior is a function that runs on the actor's fiber until it exits.
 */
alias ActorBehavior = void function(Actor*) nothrow;

struct Actor
{
    ActorId id;
    Mailbox* mailbox;
    SchedFiber* fiber;
    ActorBehavior behavior;
    bool alive;

    static Actor* create(ActorBehavior behavior, size_t mailboxCapacity = 64) nothrow @trusted
    {
        ensureScheduler();
        auto a = cast(Actor*) malloc(Actor.sizeof);
        if (a is null)
            return null;
        a.id = gScheduler.allocActorId();
        a.behavior = behavior;
        a.alive = true;
        a.mailbox = Mailbox.create(mailboxCapacity);
        if (a.mailbox is null)
        {
            free(a);
            return null;
        }
        registerActor(a);
        a.fiber = gScheduler.spawnFiber(&actorEntryThunk, a.id);
        if (a.fiber is null)
        {
            unregisterActor(a.id);
            a.mailbox.destroy();
            free(a);
            return null;
        }
        return a;
    }

    bool send(ActorId from, void* payload, size_t nbytes) nothrow @trusted
    {
        if (!alive || mailbox is null)
            return false;
        Message m;
        m.from = from;
        m.to = id;
        m.payload = payload;
        m.payloadBytes = nbytes;
        return mailbox.tryPush(m);
    }

    bool receive(out Message msg) nothrow @trusted
    {
        if (mailbox is null)
            return false;
        return mailbox.tryPop(msg);
    }

    void destroy() nothrow @trusted
    {
        unregisterActor(id);
        alive = false;
        if (mailbox !is null)
        {
            mailbox.destroy();
            mailbox = null;
        }
        free(cast(void*)&this);
    }
}

enum size_t maxActors = 1024;
__gshared Actor*[maxActors] actorTable;
__gshared size_t actorCount;

void registerActor(Actor* a) nothrow @trusted
{
    if (a is null || actorCount >= maxActors)
        return;
    actorTable[actorCount++] = a;
}

void unregisterActor(ActorId id) nothrow @trusted
{
    foreach (i; 0 .. actorCount)
    {
        if (actorTable[i] !is null && actorTable[i].id == id)
        {
            actorTable[i] = actorTable[actorCount - 1];
            actorTable[actorCount - 1] = null;
            actorCount--;
            return;
        }
    }
}

Actor* findActor(ActorId id) nothrow @trusted
{
    foreach (i; 0 .. actorCount)
    {
        if (actorTable[i] !is null && actorTable[i].id == id)
            return actorTable[i];
    }
    return null;
}

Actor* selfActor() nothrow @trusted
{
    auto sf = gScheduler.currentFiber();
    if (sf is null)
        return null;
    return findActor(sf.owner);
}

private void actorEntryThunk() nothrow @trusted
{
    auto self = selfActor();
    if (self is null || self.behavior is null)
        return;
    self.behavior(self);
    self.alive = false;
}

bool send(ActorId to, ActorId from, void* payload, size_t nbytes) nothrow @trusted
{
    auto a = findActor(to);
    if (a is null)
        return false;
    return a.send(from, payload, nbytes);
}

Actor* spawn(ActorBehavior behavior, size_t mailboxCapacity = 64) nothrow @trusted
{
    return Actor.create(behavior, mailboxCapacity);
}

void run() nothrow @trusted
{
    ensureScheduler();
    gScheduler.runUntilIdle();
}
