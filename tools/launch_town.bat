@echo off
REM Dev quick-start (v5 AA6): boots straight into town_hub, skipping the main menu.
REM Same as New Game (main_menu.gd _on_new_game just changes to town_hub.tscn).
REM The project's default run/main_scene (main menu) is unchanged.
REM Extra args are passed through, e.g.  tools\launch_town.bat --windowed
setlocal
set "PROJECT=%~dp0.."
"Z:\godot\godot.exe" --path "%PROJECT%" res://scenes/zones/town_hub.tscn %*
endlocal
