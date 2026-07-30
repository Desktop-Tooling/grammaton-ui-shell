module beam.types;

/**
 * Shared identifiers and message envelope for the actor runtime.
 * Phase 1 keeps payloads as opaque pointers so the core stays UI-free.
 */
@safe:

alias ActorId = ulong;

enum ActorId invalidActorId = 0;

struct Message
{
    ActorId from;
    ActorId to;
    /// Opaque payload owned by the sender protocol; runtime does not free it.
    void* payload;
    size_t payloadBytes;
}
