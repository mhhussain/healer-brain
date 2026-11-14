class_name Pack
extends RefCounted

# A group of enemies that fights as one: hit one and they all come.

var id := 0
var name := ""
var boss := false
## Boss rooms: the line shown when the room is cleared.
var lamp := ""
var units: Array[Combatant] = []
var engaged := false
var cleared := false
var engaged_at := 0.0
var cleared_at := 0.0
## When the tank first hit something in it, or -1.
var tank_hit_at := -1.0
## Where the party is put back after being beaten here.
var entry := Vector3.ZERO
