class_name Cast
extends RefCounted

# A cast in progress, a hero's or an enemy's.

var name := ""
var t := 0.0
var total := 0.0
var target_id := 0
## Heroes: which of the hero's abilities it is.
var ab_idx := -1
## Enemies: the ability being cast.
var ab: EnemyAbility
var interruptible := false
var importance := 1
## The hero the party has given this interrupt to, and when.
var assignee := 0
var assigned_at := 0.0
var tick_timer := 1.0
## The way an aimed cast points along the floor; zero if it is not aimed.
var dir := Vector3.ZERO
