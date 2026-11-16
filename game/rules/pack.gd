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
## Where the tank stops to pull it from, and where it then plants its feet: well inside the
## room, so the whole party follows it in.
var pull_from := Vector3.ZERO
var stand := Vector3.ZERO
## The room it stands in: a place in the level's rooms, or -1.
var room := -1
## A patrol: the spots it walks between until it is woken, which of them it is walking to, and
## where its middle is now. Empty for a pack that keeps its posts.
var path: Array[Vector3] = []
var path_i := 0
var at := Vector3.ZERO
