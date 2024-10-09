# 🍨 Scoopet 🍨

[![Excavator](https://github.com/lsq/scoopet/actions/workflows/schedule.yml/badge.svg)](https://github.com/lsq/scoopet/actions/workflows/schedule.yml)
[![Build status](https://ci.appveyor.com/api/projects/status/0kq8cy09ou8i8ga9/branch/master?svg=true)](https://ci.appveyor.com/project/lsq/scoopet/branch/master)
[![license](https://img.shields.io/github/license/ivaquero/scoopet)](https://github.com/ivaquero/scoopet/blob/master/LICENSE)
[![code size](https://img.shields.io/github/languages/code-size/ivaquero/scoopet.svg)](https://img.shields.io/github/languages/code-size/ivaquero/scoopet.svg)
[![repo size](https://img.shields.io/github/repo-size/ivaquero/scoopet.svg)](https://img.shields.io/github/repo-size/ivaquero/scoopet.svg)

A Bucket for the Best Windows Package Manager [Scoop](https://github.com/ScoopInstaller/Scoop): Continuously Assisting in Academic Research.

> If you would like to be a co-maintainer, feel free to tell me in the Discussion.

<p align="left">
<a href="README.md">English</a> |
<a href="README-CN.md">简体中文</a>
</p>

For ones familiar with Scoop:

```powershell
scoop bucket add scoopet https://github.com/ivaquero/scoopet
```

# :running: To Start

## :bike: Install Scoop

### :computer: Step 1: Enable remote policy in PowerShell

```powershell
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
```

### :gear: Step 2: Download and install Scoop

```powershell
irm get.scoop.sh -outfile 'install.ps1'
.\install.ps1 -ScoopDir ['Scoop_Path'] -ScoopGlobalDir ['GlobalScoopApps_Path'] -NoProxy
# for example
.\install.ps1 -ScoopDir 'C:\Scoop' -ScoopGlobalDir 'C:\Program Files' -NoProxy
```

> If you skip this step, all user installed Apps and Scoop itself will live in `c:/users/user_name/scoop`.

### :book: Step 3: Glance at quick-start by `scoop help`

For more information, please visit Scoop official site at 👉 https://scoop.sh/ 👈

## :car: Install Apps from this bucket

### :train: Step 1: Install Aria2 to accelerate downloading

```powershell
scoop install aria2
```

### :ticket: Step 2: Install Git to add new repositories

```powershell
scoop install git
```

if you are using VPN, you need to turn off aria2 before installing Apps

```powershell
scoop config aria2-enabled false
```

### :airplane: Step 3: Add this wonderful bucket and update, mo-mo-da~ :kiss:

```powershell
scoop bucket add scoopet https://github.com/ivaquero/scoopet
scoop update
```

### :rocket: Step 4: Install Apps

#### Check the exact name of App by `scoop search`

```powershell
scoop search <app_name>
```

#### Install Apps with assistance of plugin `scoop-completion`

```powershell
scoop install scoop-completion
scoop install <app_name>
```

> to use `scoop-completion`, just to hit `tab` after initial letters of App names

### :100: Step 5: List the official recommended buckets by `scoop bucket known`

```powershell
scoop bucket known

main [default]
extras [strongly recommended]
versions
nightlies
nirsoft
php
nerd-fonts
nonportable
java
games
jetbrains
```

## :m: Trivial

### Tweak with Parameters in Aria2

```powershell
scoop config aria2-enabled true
scoop config aria2-retry-wait 4
scoop config aria2-split 16
scoop config aria2-max-connection-per-server 16
scoop config aria2-min-split-size 4M
```

## :star: Summary

### Research Tools

|        App         | Auto-Update ? |                              Original ?                               |
| :----------------: | :-----------: | :-------------------------------------------------------------------: |
|        Buzz        |       ✓       | copied from [anderlli0053](https://github.com/anderlli0053/DEV-tools) |
| Jupyterlab-Desktop |       ✓       |        modified [gdm257](https://github.com/gdm257/scoop-257)         |
|      KingDraw      |       ✓       |                                   ✓                                   |
|  Mendeley-Desktop  |       ✓       |                                   ✓                                   |
|      NetLogo       |       ✓       |                                   ✓                                   |
|     SciHubEVA      |       ✓       |                                   ✓                                   |
|      TeXLive       |       ✓       |       modified [chawyehsu](https://github.com/chawyehsu/dorado)       |

### Development Auxiliary

|          App           | Auto-Update ? |                         Original ?                          |
| :--------------------: | :-----------: | :---------------------------------------------------------: |
|      AutoDarkMode      |       ✓       |                              ✓                              |
|        ChatBox         |       ✓       |                              ✓                              |
|      Doxygen-GUI       |       ✓       |                              ✓                              |
|        escrcpy         |       ✓       |   copied from [DoveBoy](hhttps://github.com/DoveBoy/Apps)   |
|     FileCentipede      |       ✓       |                      ✓ (by @CronusLM)                       |
|      Pot-Desktop       |       ✓       |                              ✓                              |
|      RectangleWin      |       ✓       |                              ✓                              |
|        Veracypt        |       ✓       |                              ✓                              |
|         Viber          |       ✓       | copied from [okibcn](https://github.com/okibcn/ScoopMaster) |
|         WinRAR         |       ✓       |                              ✓                              |
|      WiseCare365       |       ✓       |                              ✓                              |
| VMware-Workstation-Pro |       ✓       |  modified [Ash258](https://github.com/Ash258/Scoop-Ash258)  |

### Windows-Only

|       App       | Auto-Update ? |                       Original ?                        |
| :-------------: | :-----------: | :-----------------------------------------------------: |
| LKY-Officetools |       ✓       | copied from [DoveBoy](hhttps://github.com/DoveBoy/Apps) |
|  RectangleWin   |       ✓       |                            ✓                            |

### CLI

|     App     | Auto-Update ? | Original ? |
| :---------: | :-----------: | :--------: |
| MicroMamba  |       ✓       |     ✓      |
| N-m3u8DL-RE |       ✓       |     ✓      |
