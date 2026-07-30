module beam;

/**
 * libbeam_d — Erlang-style actor runtime for Actor Shell.
 *
 * Phase 1: M:N fiber scheduler (single worker) + lock-free MPSC mailbox.
 * Phase 2 (next): supervision trees (link / monitor / restart).
 */
public import beam.types;
public import beam.mailbox;
public import beam.scheduler;
public import beam.actor;
