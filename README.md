# Fourfold

A solo, browser-based dungeon runner in the style of timed MMO dungeons. You play one hero — tank, healer or damage — and AI plays the other three.

- **Play:** https://mhhussain.github.io/healer-brain/
- **Design:** [DESIGN.md](DESIGN.md)

## Develop

```
npm install
npm run dev      # local server
npm test         # simulation and interface tests
npm run sim -- 1,5,8 2   # all-AI balance runs: levels, seeds
npm run build    # production build in dist/
```

Pushing to `main` builds and publishes to GitHub Pages.
