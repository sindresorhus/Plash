<div align="center">
	<a href="https://sindresorhus.com/plash">
		<img src="Stuff/AppIcon-readme.png" width="200" height="200">
	</a>
	<h1>Plash</h1>
	<p>
		<b>Make any website your Mac desktop wallpaper</b>
	</p>
	<br>
	<br>
	<br>
</div>

Plash enables you to have a highly dynamic desktop wallpaper. You could display your favorite news site, Facebook feed, or a random beautiful scenery photo. The use-cases are limitless. You could even set an animated GIF as wallpaper. You can even add multiple websites and easily switch between them.

## Use-cases

- [**Random Unsplash image**](https://source.unsplash.com)\
	Example: https://source.unsplash.com/random/2880x1756?puppy \
		This returns a new random puppy image each time.
	See the [tip](#tips) on how to get exact screen size.
- [**Bing Photo of the Day**](https://github.com/sindresorhus/plash-bing-photo-of-the-day)
- **Calendar**\
	For example, Google Calendar or Outlook 365.
- **Personal stats**\
	You could even make a custom website for this.
- [**Random street view image**](https://randomstreetview.com/#slideshow)
- **Animated GIF**\
	Example: https://media3.giphy.com/media/xTiTnLmaxrlBHxsMMg/giphy.gif?cid=790b761121c10e72aca8bcfe50b030502b62a69ac7336782&rid=giphy.gif
- [**Random color**](https://www.color.pizza)
- **Build a custom website**\
	You could build something quick and host it on [GitHub Pages](https://pages.github.com), [jsfiddle](https://jsfiddle.net), or [CodePen](https://codepen.io).

[*Share your use-case*](https://github.com/sindresorhus/Plash/discussions/136)

## Features

- Show a remote or local website
- Interact with the website (“Browsing Mode”)
- Automatically reload the website at a custom interval
- Add multiple websites
- Show the website on a different display
- Invert website colors (fake dark mode)
- Add custom CSS and JavaScript to the website
- Lower the opacity
- [Transparent background](https://github.com/sindresorhus/Plash/issues/1#issuecomment-573513816)
- Automatically deactivate while on battery
- Audio is muted
- Single image will be aspect-filled to your screen
- Hide menu bar icon
- Shortcuts support
- [Scriptable](#scripting)
- [Share extension](#share-extension)

## Download

[![](https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/en-us?size=250x83&releaseDate=1615852800)](https://apps.apple.com/app/id1494023538)

Requires macOS 13 or later.

**Older versions**

- [2.12.1](https://github.com/sindresorhus/Plash/releases/download/v2.12.1/Plash.2.12.1.-.macOS.12.zip) for macOS 12+
- [2.10.1](https://github.com/sindresorhus/Plash/releases/download/v2.10.1/Plash.2.10.1.-.macOS.11.zip) for macOS 11+
- [2.1.0](https://github.com/sindresorhus/Plash/releases/download/v2.1.0/Plash.2.1.1.-.macOS.10.15.zip) for macOS 10.15+

**Non-App Store version**

A special version for users that cannot access the App Store. It won't receive automatic updates. I will update it here once a year.

[Download](https://www.dropbox.com/scl/fi/lr55dpcqmwxz1hkn5big8/Plash-2.15.0-1705418289.zip?rlkey=smxibxghlw9c153i2kbzhoela&raw=1) *(2.15.0 · macOS 14+)*

## Tips

### Browsing mode

You can interact with the website by enabling “Browsing Mode”. When in this mode, you can right-click to be able to go back/forward, reload, and zoom in the page contents (the zoom level is saved). You can also pinch to magnify. This is different from zooming the page contents in that it will zoom in to a specific part of the page instead of just enlarging everything.

Plash injects a CSS class named `plash-is-browsing-mode` on the `<html>` element while browsing mode is active. You could use this class to customize the website for browsing mode.

If clicking a link opens it in a new window, you can hold the <kbd>Option</kbd> key while clicking the link to open it in the main Plash window.

### Zoom in website

To zoom in the website, activate “Browsing Mode”, right-click the website, and then select “Zoom In”.

### URL placeholders for screen width and height

Use `[[screenWidth]]` and `[[screenHeight]]` in any URL and Plash will substitute the right values for you. For example, `https://source.unsplash.com/random/[[screenWidth]]x[[screenHeight]]?puppy`.

### Scroll to position

You can scroll a website to a specific position each time it is loaded by putting the following in the website's “JavaScript” field. Adjust the “500” to how far down it should scroll.

```js
window.scrollTo(0, 500);
```

You can also [scroll to a specific element](https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView) matching a [CSS selector](https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Selectors):

```js
document.querySelector('.title')?.scrollIntoView();
```

### Make the website occupy only half the screen

You can use the “CSS” field in the website settings to adjust the padding of the website:

```css
:root {
    margin-left: 50% !important;
}
```

### Detect Plash

Plash injects a CSS class named `is-plash-app` on the `<html>` element. You could use this class to customize your website for Plash. For example, if your website has instructions on how to use it in Plash, you could hide those when it's running in Plash.

## Screenshots

![](Stuff/screenshot1.jpg)
![](Stuff/screenshot2.jpg)
![](Stuff/screenshot3.jpg)
![](Stuff/screenshot4.jpg)
![](Stuff/screenshot5.jpg)

## Scripting

You can control Plash using anything that supports opening a URL with a custom scheme.

For example, to reload the current website, run this terminal command:

```console
$ open -g plash:reload
```

## Share extension

Plash comes bundled with a [share extension](https://support.apple.com/guide/mac-help/use-the-share-menu-on-mac-mh40614/mac). You can, for example, use it to quickly add a website you have open in Safari to Plash.

### Tools

- [plash-cli](https://github.com/sindresorhus/plash-cli) - Command-line tool.
- [alfred-plash](https://github.com/sindresorhus/alfred-plash) - Alfred workflow.
- [Raycast commands](https://github.com/raycast/script-commands/tree/master/commands#plash)

### Commands

#### `add`

Add a website to Plash.

You can optionally specify a title. If no title is given, a title will be automatically fetched from the website.

```console
$ open -g 'plash:add?url=https://sindresorhus.com/plash&title=Plash%20website'
```

*Don't forget to correctly encode query parameters.*

**Note:** Local file URLs are not supported.

#### `reload`

Reload the current website.

```console
$ open -g plash:reload
```

#### `next`

Switch to the next website in the list.

```console
$ open -g plash:next
```

#### `previous`

Switch to the previous website in the list.

```console
$ open -g plash:previous
```

#### `random`

Switch to a random website in the list.

It will never show the same website twice in a row, unless you only have a single website.

```console
$ open -g plash:random
```

#### `toggle-browsing-mode`

Toggle browsing mode.

```console
$ open -g plash:toggle-browsing-mode
```

### Examples

#### Node.js

```js
import {execFileSync} from 'node:child_process';

execFileSync('open', ['--background', 'plash:reload']);
```

#### Swift

```swift
import Cocoa

let command = "plash:reload"

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
NSWorkspace.shared.open(URL(string: command)!, configuration: configuration)
```

#### AppleScript

```applescript
do shell script "open --background 'plash:reload'"
```

#### Python

```python
import subprocess

subprocess.run(['open', '--background', 'plash:reload'])
```

## FAQ

#### The app does not show up in the menu bar

macOS hides menu bar apps when there is no space left in the menu bar. This is a common problem on MacBooks with a notch. Try quitting some menu bar apps to free up space. If this does not solve it, try quitting Bartender if you have it installed.

#### Can it automatically switch websites every 10 minutes?

Plash can be automated with the built-in Shortcuts app, for example, using the “Switch to Next Website” action. Shortcuts on macOS does not yet support automations, but for now, you can use the [Shortery app](https://apps.apple.com/app/id1594183810).

#### Does it support multiple displays?

Support for multiple displays is currently limited to the ability to choose which display to show the website on. Support for setting a separate website for each display is [planned](https://github.com/sindresorhus/Plash/issues/2).

However, I there is a [workaround](https://github.com/sindresorhus/Plash/issues/2#issuecomment-653891524).

#### Why does Plash use so much memory?

Plash uses very little memory. Usually around 40 MB. However, the websites you display can take up a lot of memory, and sometimes even have a memory leaks.

#### The menu bar does not adapt to the Plash wallpaper

The menu bar adapts its color from the actual system wallpaper. Plash is not actually a wallpaper, but rather runs right above the wallpaper. So Plash cannot influence the menu bar color.

#### Can Plash block ads?

Not built-in, but you can block ads system-wide with a [DNS ad-blocker](https://alternate-dns.com).

#### How can I switch to a specific website with a keyboard shortcut?

Make a shortcut in the Shortcuts app that uses the “Set Current Website” action and then set a keyboard shortcut for the shortcut.

#### Can I contribute localizations?

I don't have any immediate plans to localize the app.

#### What does “Plash” mean?

[Click here.](http://letmegooglethat.com/?q=define+plash)

## Built with

- [Defaults](https://github.com/sindresorhus/Defaults) - Swifty and modern UserDefaults
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Add user-customizable global keyboard shortcuts to your macOS app

## Links

- [More apps by me](https://sindresorhus.com/apps)
