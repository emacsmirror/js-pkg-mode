# js-pkg-mode

A comprehensive [Emacs](https://www.gnu.org/software/emacs/) minor mode for working with JavaScript/TypeScript projects. Supports multiple package managers and runtimes:
- npm
- yarn
- pnpm
- bun
- deno

## Installation

### Via MELPA (Recommended)
The package is available on [MELPA](https://melpa.org/#/). Install using your preferred package manager.

### straight.el
```elisp
(straight-use-package
 '(js-pkg-mode :type git :host github :repo "ovistoica/js-pkg-mode"))

;; or
(use-package js-pkg-mode
  :straight '(js-pkg-mode :type git :host github :repo "ovistoica/js-pkg-mode")
  :init (js-pkg-global-mode 1))
```

### Manual Installation
```elisp
(add-to-list 'load-path "/path/to/js-pkg-mode")
(require 'js-pkg-mode)
```

## Configuration

Enable the mode either globally or per-project:

```elisp
;; Global activation
(js-pkg-global-mode)
```

The default keymap prefix is <kbd>C-c n</kbd> and can be customized via `js-pkg-mode-keymap-prefix`.

## Features

### Command Keymap

| Command | Keymap | Description |
|---------|--------|-------------|
| js-pkg-init | <kbd>n</kbd> | Initialize new project |
| js-pkg-install | <kbd>i</kbd> | Install all dependencies |
| js-pkg-install-save | <kbd>s</kbd> | Add new dependency |
| js-pkg-install-save-dev | <kbd>d</kbd> | Add new dev dependency |
| js-pkg-uninstall | <kbd>u</kbd> | Remove dependency |
| js-pkg-list | <kbd>l</kbd> | List installed dependencies |
| js-pkg-run | <kbd>r</kbd> | Run project script |
| js-pkg-visit-project-file | <kbd>v</kbd> | Visit project file |
| | <kbd>?</kbd> | Display keymap commands |

### Package Manager Auto-detection
The mode automatically detects which package manager to use based on your project's lock file:
- `package-lock.json` → npm
- `yarn.lock` → yarn
- `pnpm-lock.yaml` → pnpm
- `bun.lock` → bun
- `deno.json`/`deno.jsonc` → deno

## Credits
This is a fork of [npm-mode](https://github.com/mojochao/npm-mode), expanded to support the broader JavaScript ecosystem.
