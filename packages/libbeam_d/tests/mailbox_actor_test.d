module beam_tests;

import beam.mailbox;
import beam.actor;
import beam.types;
import beam.scheduler;

@("mailbox push/pop preserves order")
unittest
{
    auto mb = Mailbox.create(8);
    assert(mb !is null);
    Message m;
    m.from = 1;
    m.to = 2;
    m.payload = cast(void*) 0xABC;
    m.payloadBytes = 4;
    assert(mb.tryPush(m));
    Message outMsg;
    assert(mb.tryPop(outMsg));
    assert(outMsg.from == 1);
    assert(outMsg.to == 2);
    assert(outMsg.payload == cast(void*) 0xABC);
    assert(outMsg.payloadBytes == 4);
    assert(!mb.tryPop(outMsg));
    mb.destroy();
}

__gshared int pingCount;
__gshared ActorId pongId;

void pongBehavior(Actor* self) nothrow
{
    Message msg;
    foreach (i; 0 .. 10_000)
    {
        if (self.receive(msg))
        {
            pingCount++;
            return;
        }
        gScheduler.tick();
    }
}

void pingBehavior(Actor* self) nothrow
{
    send(pongId, self.id, null, 0);
}

@("spawn ping/pong delivers one message")
unittest
{
    pingCount = 0;
    ensureScheduler();
    gScheduler.init();
    actorCount = 0;
    foreach (i; 0 .. maxActors)
        actorTable[i] = null;

    auto pong = spawn(&pongBehavior);
    assert(pong !is null);
    pongId = pong.id;
    auto ping = spawn(&pingBehavior);
    assert(ping !is null);
    run();
    assert(pingCount == 1);
}
