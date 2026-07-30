module beam.mailbox;

import core.atomic;
import core.stdc.stdlib : malloc, free;
import beam.types : Message;

/**
 * Bounded lock-free MPSC mailbox.
 *
 * Multiple producers push; a single consumer (the actor fiber) pops.
 * Uses a circular buffer of Message slots with acquire/release indices.
 */
struct Mailbox
{
@nogc nothrow:

    private Message* slots;
    private size_t capacity;
    private size_t mask;
    private shared size_t head; // consumer
    private shared size_t tail; // producers

    @disable this();

    static Mailbox* create(size_t capacityPowerOfTwo) @trusted
    {
        assert(capacityPowerOfTwo >= 2);
        assert((capacityPowerOfTwo & (capacityPowerOfTwo - 1)) == 0);

        auto mb = cast(Mailbox*) malloc(Mailbox.sizeof);
        if (mb is null)
            return null;
        mb.capacity = capacityPowerOfTwo;
        mb.mask = capacityPowerOfTwo - 1;
        mb.head = 0;
        mb.tail = 0;
        mb.slots = cast(Message*) malloc(Message.sizeof * capacityPowerOfTwo);
        if (mb.slots is null)
        {
            free(mb);
            return null;
        }
        foreach (i; 0 .. capacityPowerOfTwo)
            mb.slots[i] = Message.init;
        return mb;
    }

    void destroySlots() @trusted
    {
        if (slots !is null)
        {
            free(slots);
            slots = null;
        }
    }

    void destroy() @trusted
    {
        destroySlots();
        free(cast(void*)&this);
    }

    /// Returns false if the mailbox is full.
    bool tryPush(Message msg) @trusted
    {
        while (true)
        {
            immutable t = atomicLoad!(MemoryOrder.raw)(tail);
            immutable h = atomicLoad!(MemoryOrder.acq)(head);
            if (t - h >= capacity)
                return false;
            if (cas(&tail, t, t + 1))
            {
                slots[t & mask] = msg;
                return true;
            }
        }
    }

    /// Returns false if empty.
    bool tryPop(out Message msg) @trusted
    {
        immutable h = atomicLoad!(MemoryOrder.raw)(head);
        immutable t = atomicLoad!(MemoryOrder.acq)(tail);
        if (h == t)
            return false;
        msg = slots[h & mask];
        atomicStore!(MemoryOrder.rel)(head, h + 1);
        return true;
    }

    size_t length() const @trusted
    {
        immutable t = atomicLoad!(MemoryOrder.acq)(tail);
        immutable h = atomicLoad!(MemoryOrder.acq)(head);
        return t - h;
    }
}
