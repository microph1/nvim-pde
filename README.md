# 🔧 Personal Development Environment

> Maybe the most important thing in using a development environment like Neovim is that you can truly make it your own

This repo contains my attempt to make Neovim __my own__ development environment.
I mostly develop web application with Angular and Typescript also for the backend.

This plugin may or may not contain other features in the future but for now it just contains an autocompletion system for css classes in html files.

A know plugin for this is [https://github.com/Jezda1337/nvim-html-css](https://github.com/Jezda1337/nvim-html-css) from which I took inspiration for writing this plugin.

### The problem

Suggesting completions of available class names in a given html tag's class attribute may seem trivial but is NOT really, especially if we put in the game `scss`. In fact one should compile all files to `css` before scanning them to offer all possible suggestions. But compiling the `scss` files of a medium size project may be a slow task and adds unnecessary load on the cpu which probably has already a process running that is doing the same thing.

### My approach

To guarantee a smooth development experience and a precise completion I start from the following assumptions:

 - the developer has already a process running that is watching and compiling the all `scss` files when needed
 - the output of such a process is one or more files served through http

> I.e.: considering, for example, an Angular application in dev mode served at `http://localhost:4200/styles.css`



## 📦 Installation

 - This plugin works only with [lazy.nvim](https://github.com/folke/lazy.nvim) and it relies on the fact that it can be loaded when a given file type is opened. Other package manager are not supported.
#### This plugin works only if a `package.json` file is present and its position will mark the application's root folder. I.e.: in a monorepo setup with several nested package.json files the closer parent folder containing such file will be considered the root of the applicaiton.
#### The plugin is activated on if an object as described below is present in the `package.json`

> [!]
> If you have different needs in your journey to the coding nirvana please: fork or make a PR or open in issue.


## Lazy

```lua
{
    "microph1/nvim-pde",
    -- this are the files tipes that trigger the loading of the plugin
    -- htlm is mandatory, styles types can be omitted but are suggested
    ft = {"html", "scss"},
    dependencies = {
        'nvim/nvim-cmp',
    },
    config = function(opts)
        require('pde'):setup(opts.opts);
    end
}
```

## ⚙ Configuration
In `package.json`
```json
{
    "nvim": {
        "pde": {
            "styles": [
                "http://localhost:4200/styles.css"
            ]
        }
    }
}
```
