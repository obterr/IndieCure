extends Control

signal close


func close_panel():
	close.emit(self)

func get_tighble():
	Global.player.inventory.insert(load("res://Weapons/Thighble/Tighble.tres"))
	close_panel()