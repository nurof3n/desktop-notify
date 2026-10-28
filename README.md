# desktop-notify

A Claude Code plugin for Linux desktops. It shows a desktop notification and plays a sound when:

- Claude Code asks for permission to use a tool.
- Claude Code finishes a response.

The notification shows the name of the project directory of the session.

## Requirements

| Tool | Use | Ubuntu / Debian package | Arch package |
|---|---|---|---|
| `notify-send` | Shows the notification | `libnotify-bin` | `libnotify` |
| `paplay` or `pw-play` | Plays the sound | `pulseaudio-utils` or `pipewire-bin` | `libpulse` or `pipewire` |
| Sound files | The sounds | `sound-theme-freedesktop` | `sound-theme-freedesktop` |

Most desktop installations already have these tools. To install all of them on Ubuntu:

```sh
sudo apt install libnotify-bin pulseaudio-utils sound-theme-freedesktop
```

If a tool is missing, the plugin does the other steps. For example, without a sound player you get only the
notification.

## Install

In Claude Code, run:

```
/plugin marketplace add nurof3n/desktop-notify
/plugin install desktop-notify@nurof3n
```

Then restart Claude Code.

If you have the same hooks in `~/.claude/settings.json`, remove them. If you do not remove them, you get two
notifications for each event.

## Test

Start Claude Code and send a prompt. When Claude finishes the response, you get a notification and a sound.

## Update

```
/plugin marketplace update nurof3n
/plugin update desktop-notify@nurof3n
```

## Change the sounds or the volume

Fork this repository, edit `hooks/hooks.json`, and install the plugin from your fork. Each hook calls:

```
notify-handler.sh MESSAGE SOUND_FILE VOLUME
```

`VOLUME` is an integer from 0 to 100. If the value is not an integer, the plugin uses 100.
