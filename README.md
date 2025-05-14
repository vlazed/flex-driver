# Flex Driver <!-- omit from toc -->

Change a bone pose based on a certain parameter, such as a flex value or entity property

## Table of Contents <!-- omit from toc -->

- [Description](#description)
  - [Features](#features)
  - [Rational](#rational)
  - [Remarks](#remarks)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)

## Description

This adds a "Blender" driver system for GMod bones.

### Features

- Expression parsing using [MathParser](https://github.com/bytexenon/MathParser.lua/tree/v1.0.3)
- Multiple drivers with `ADD` and `REPLACE` operations
- Entity hierarchy to select bonemerged entities for editing
- Preset system to save drivers and apply them to any entity

### Rational

Source Engine only supports driving flex values from a bone's translation, via `$boneflexdriver` qc command. A "`$flexbonedriver`" qc command does not exist. Hence, this repository aims to simulate such behavior in GMod Lua.

This tool was originally made to make alleviate the effort of animating models where most of their facial structure is controlled by nonphysical bones, rather than by flex (shapekey) values.

### Remarks

## Disclaimer

**This tool has been tested in singleplayer.** Although this tool may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
