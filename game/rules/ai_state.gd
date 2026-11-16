class_name AIState
extends RefCounted

# What an AI hero remembers from one tick to the next. Spots are a Vector3, or null for none.

## Seconds it takes to notice a telegraph or a cast: 0.3 to 0.6, fixed for the run.
var reaction := 0.4
## Where it is running to get out of a telegraph.
var escape = null
## Ranged heroes: the spot it is holding, and when it next looks for a better one.
var pos = null
var pos_t := 0.0
## The tank: where it has planted its feet.
var tank_spot = null
## Where it is hiding from a cast the party must hide from.
var hide = null
## The tank has gone in: it has reached the spot it holds this pull at.
var arrived := false
## It was walking last tick. Goals use it so a hero does not start and stop on a threshold.
var moving := false
