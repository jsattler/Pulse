# Astro Starter Kit: Basics

## Layout

- Navbar: Logo + Title (left), Notch (center), GitHub + GitHub Sponsor + BuyMeACoffee
  - Navbar should be in the style like a macoOS menu bar, with the notch in the center
- Hero:
  - Use the wallpaper to fill the entire viewport
  - Header (Center and white font)
  - Subheader (center and muted font)
  - install instructions ()
- very basic footer at the bottom.

## Fonts

Normal:

```
font-family: system-ui, sans-serif;
font-weight: normal;
```

Monospace

```
font-family: 'Nimbus Mono PS', 'Courier New', monospace;
font-weight: 500;
```

## 🧞 Commands

All commands are run from the root of the project, from a terminal:

| Command                | Action                                           |
| :--------------------- | :----------------------------------------------- |
| `pnpm install`         | Installs dependencies                            |
| `pnpm dev`             | Starts local dev server at `localhost:4321`      |
| `pnpm build`           | Build your production site to `./dist/`          |
| `pnpm preview`         | Preview your build locally, before deploying     |
| `pnpm astro ...`       | Run CLI commands like `astro add`, `astro check` |
| `pnpm astro -- --help` | Get help using the Astro CLI                     |
