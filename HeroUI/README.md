# TuJu’s HeroUI controls

The iPhone and Mac targets use the same bundled HeroUI controls for the Home journey panel and the four main navigation tabs. The Home sheet uses HeroUI Button and HeroUI Pro ItemCard. The main tabs use HeroUI Pro Navbar. The glass theme, TuJu colors, local Figma icons and tab glyphs compile into the bundled HTML. SwiftUI supplies the current destination and selected tab and handles navigation, location and saved places.

## Rebuild the controls

Xcode uses the checked-in `TuJu/HeroUIControls.html`. Node is needed only to edit or regenerate these controls. With Node 24, pnpm 11 and access to the licensed HeroUI Pro package, run these commands inside `HeroUI/`.

```sh
pnpm install --frozen-lockfile
pnpm build
```

The build bundles React, styles, icons and third-party notices into one offline resource. The content security policy uses a hash of the production script. Changing a source control requires rebuilding the HTML before running Xcode.

On a machine that has never installed HeroUI Pro, authenticate the official CLI with the licensed account before installing dependencies. [HeroUI Pro installation](https://heroui.pro/docs/react/getting-started/installation)
